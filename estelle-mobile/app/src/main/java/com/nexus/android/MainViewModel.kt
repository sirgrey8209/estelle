package com.nexus.android

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

data class DeviceInfo(
    val deviceId: String,
    val deviceType: String,
    val connectedAt: String
)

data class ChatMessage(
    val from: String,
    val deviceType: String?,
    val message: String,
    val timestamp: String,
    val time: String
)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    // 프로덕션 URL 사용
    private val relayUrl = "wss://estelle-relay.fly.dev"
    private val deviceId = "mobile"

    private val relayClient = RelayClient(relayUrl, deviceId)
    val updateChecker = UpdateChecker(application)

    val isConnected: StateFlow<Boolean> = relayClient.isConnected
    val messages: StateFlow<List<String>> = relayClient.messages

    private val _devices = MutableStateFlow<List<DeviceInfo>>(emptyList())
    val devices: StateFlow<List<DeviceInfo>> = _devices

    private val _chatMessages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val chatMessages: StateFlow<List<ChatMessage>> = _chatMessages

    private val _updateInfo = MutableStateFlow<UpdateChecker.UpdateInfo?>(null)
    val updateInfo: StateFlow<UpdateChecker.UpdateInfo?> = _updateInfo

    private val _downloadProgress = MutableStateFlow(-1)
    val downloadProgress: StateFlow<Int> = _downloadProgress

    init {
        // Relay 메시지 콜백 설정
        relayClient.setOnDataCallback { data ->
            handleRelayMessage(data)
        }

        // 앱 시작 시 업데이트 확인
        checkForUpdate()
    }

    private fun handleRelayMessage(data: Map<String, Any?>) {
        when (data["type"]) {
            "deviceStatus", "deviceList" -> {
                val devicesList = (data["devices"] as? List<*>)?.mapNotNull { device ->
                    (device as? Map<*, *>)?.let {
                        DeviceInfo(
                            deviceId = it["deviceId"] as? String ?: "",
                            deviceType = it["deviceType"] as? String ?: "unknown",
                            connectedAt = it["connectedAt"] as? String ?: ""
                        )
                    }
                } ?: emptyList()
                _devices.value = devicesList
            }
            "chat" -> {
                val timestamp = data["timestamp"] as? String ?: ""
                val time = try {
                    val instant = java.time.Instant.parse(timestamp)
                    java.time.format.DateTimeFormatter.ofPattern("HH:mm")
                        .withZone(java.time.ZoneId.systemDefault())
                        .format(instant)
                } catch (e: Exception) {
                    ""
                }

                val chatMessage = ChatMessage(
                    from = data["from"] as? String ?: "unknown",
                    deviceType = data["deviceType"] as? String,
                    message = data["message"] as? String ?: "",
                    timestamp = timestamp,
                    time = time
                )
                _chatMessages.value = (_chatMessages.value + chatMessage).takeLast(200)
            }
            "deployNotification" -> {
                // 실행 중 새 배포 알림 → 업데이트 확인
                checkForUpdate()
            }
        }
    }

    fun connect() {
        relayClient.connect()
    }

    fun disconnect() {
        relayClient.disconnect()
    }

    fun sendChat(message: String) {
        relayClient.sendChat(message)
    }

    fun sendPing() {
        relayClient.sendPing()
    }

    fun requestDeploy() {
        // office-pc 우선, 없으면 아무 pylon
        val pylons = _devices.value.filter { it.deviceType == "pylon" }
        val target = pylons.find { it.deviceId == "office-pc" }
            ?: pylons.firstOrNull()

        relayClient.sendDeployRequest(target?.deviceId)
    }

    fun checkForUpdate() {
        viewModelScope.launch {
            val info = updateChecker.checkForUpdate()
            _updateInfo.value = info
        }
    }

    fun downloadAndInstall(url: String) {
        viewModelScope.launch {
            _downloadProgress.value = 0
            val apkFile = updateChecker.downloadApk(url) { progress ->
                _downloadProgress.value = progress
            }
            _downloadProgress.value = -1

            apkFile?.let {
                updateChecker.installApk(it)
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        relayClient.disconnect()
    }
}
