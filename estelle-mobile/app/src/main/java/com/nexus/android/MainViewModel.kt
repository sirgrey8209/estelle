package com.nexus.android

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

// ============ 데이터 클래스 ============

data class DeviceInfo(
    val deviceId: Int,
    val deviceType: String,
    val name: String,
    val icon: String,
    val role: String,
    val connectedAt: String
)

data class ChatMessage(
    val from: String,
    val fromIcon: String,
    val message: String,
    val timestamp: String,
    val time: String
)

// 데스크 정보
data class DeskInfo(
    val deviceId: Int,
    val deviceName: String,
    val deviceIcon: String,
    val deskId: String,
    val deskName: String,
    val workingDir: String,
    val status: String,  // idle, working, permission, offline
    val isActive: Boolean
) {
    val fullName: String get() = "$deviceName/$deskName"
}

// Claude 이벤트
sealed class ClaudeEvent {
    data class Text(val content: String) : ClaudeEvent()
    data class ToolStart(val toolName: String, val toolInput: Map<String, Any?>, val toolUseId: String) : ClaudeEvent()
    data class ToolComplete(val toolUseId: String, val output: Any?) : ClaudeEvent()
    data class PermissionRequest(val toolName: String, val toolInput: Map<String, Any?>, val toolUseId: String) : ClaudeEvent()
    data class AskQuestion(val question: String, val options: List<String>, val toolUseId: String) : ClaudeEvent()
    data class State(val state: String) : ClaudeEvent()
    data class Result(val result: Any?) : ClaudeEvent()
    data class Error(val error: String) : ClaudeEvent()
}

// Claude 메시지 (UI용)
data class ClaudeMessage(
    val id: String,
    val deskId: String,
    val isUser: Boolean,
    val content: String,
    val timestamp: Long,
    val event: ClaudeEvent? = null
)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    // 프로덕션 URL
    private val relayUrl = "wss://estelle-relay.fly.dev"
    // 동적 디바이스 ID (100 이상)
    private val deviceId = 100 + (System.currentTimeMillis() % 900).toInt()

    private val relayClient = RelayClient(relayUrl, deviceId)
    val updateChecker = UpdateChecker(application)

    val isConnected: StateFlow<Boolean> = relayClient.isConnected
    val isAuthenticated: StateFlow<Boolean> = relayClient.isAuthenticated
    val messages: StateFlow<List<String>> = relayClient.messages

    private val _devices = MutableStateFlow<List<DeviceInfo>>(emptyList())
    val devices: StateFlow<List<DeviceInfo>> = _devices

    private val _chatMessages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val chatMessages: StateFlow<List<ChatMessage>> = _chatMessages

    private val _updateInfo = MutableStateFlow<UpdateChecker.UpdateInfo?>(null)
    val updateInfo: StateFlow<UpdateChecker.UpdateInfo?> = _updateInfo

    private val _downloadProgress = MutableStateFlow(-1)
    val downloadProgress: StateFlow<Int> = _downloadProgress

    // ============ 데스크 & Claude ============

    // deviceId -> (deviceInfo, desks)
    private val _pylonDesks = MutableStateFlow<Map<Int, Pair<DeviceInfo?, List<DeskInfo>>>>(emptyMap())

    private val _selectedDesk = MutableStateFlow<DeskInfo?>(null)
    val selectedDesk: StateFlow<DeskInfo?> = _selectedDesk

    private val _claudeMessages = MutableStateFlow<List<ClaudeMessage>>(emptyList())
    val claudeMessages: StateFlow<List<ClaudeMessage>> = _claudeMessages

    private val _currentTextBuffer = MutableStateFlow("")
    val currentTextBuffer: StateFlow<String> = _currentTextBuffer

    private val _pendingPermission = MutableStateFlow<ClaudeEvent.PermissionRequest?>(null)
    val pendingPermission: StateFlow<ClaudeEvent.PermissionRequest?> = _pendingPermission

    private val _pendingQuestion = MutableStateFlow<ClaudeEvent.AskQuestion?>(null)
    val pendingQuestion: StateFlow<ClaudeEvent.AskQuestion?> = _pendingQuestion

    private val _claudeState = MutableStateFlow("idle")
    val claudeState: StateFlow<String> = _claudeState

    // 모든 데스크 목록 (모든 Pylon에서)
    val allDesks: StateFlow<List<DeskInfo>> = MutableStateFlow(emptyList())

    init {
        relayClient.setOnDataCallback { data ->
            handleRelayMessage(data)
        }
        checkForUpdate()
    }

    private fun updateAllDesks() {
        val desks = mutableListOf<DeskInfo>()
        _pylonDesks.value.forEach { (_, pair) ->
            desks.addAll(pair.second)
        }
        (allDesks as MutableStateFlow).value = desks
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleRelayMessage(data: Map<String, Any?>) {
        when (data["type"]) {
            // 디바이스 상태
            "device_status" -> {
                val payload = data["payload"] as? Map<*, *> ?: return
                val devicesList = (payload["devices"] as? List<*>)?.mapNotNull { device ->
                    (device as? Map<*, *>)?.let {
                        DeviceInfo(
                            deviceId = (it["deviceId"] as? Number)?.toInt() ?: 0,
                            deviceType = it["deviceType"] as? String ?: "unknown",
                            name = it["name"] as? String ?: "Device",
                            icon = it["icon"] as? String ?: "💻",
                            role = it["role"] as? String ?: "unknown",
                            connectedAt = it["connectedAt"] as? String ?: ""
                        )
                    }
                } ?: emptyList()
                _devices.value = devicesList
            }

            // 채팅
            "chat" -> {
                val from = data["from"] as? Map<*, *>
                val timestamp = data["timestamp"] as? String ?: ""
                val time = try {
                    val instant = java.time.Instant.parse(timestamp)
                    java.time.format.DateTimeFormatter.ofPattern("HH:mm")
                        .withZone(java.time.ZoneId.systemDefault())
                        .format(instant)
                } catch (e: Exception) { "" }

                val chatMessage = ChatMessage(
                    from = from?.get("name") as? String ?: "unknown",
                    fromIcon = from?.get("icon") as? String ?: "💬",
                    message = data["message"] as? String ?: "",
                    timestamp = timestamp,
                    time = time
                )
                _chatMessages.value = (_chatMessages.value + chatMessage).takeLast(200)
            }

            "deployNotification" -> {
                checkForUpdate()
            }

            // 데스크 목록 (Pylon에서 브로드캐스트)
            "desk_list_result" -> {
                val payload = data["payload"] as? Map<*, *> ?: return
                val pylonDeviceId = (payload["deviceId"] as? Number)?.toInt() ?: return
                val deviceInfoMap = payload["deviceInfo"] as? Map<*, *>

                val deviceInfo = deviceInfoMap?.let {
                    DeviceInfo(
                        deviceId = (it["deviceId"] as? Number)?.toInt() ?: pylonDeviceId,
                        deviceType = it["deviceType"] as? String ?: "pylon",
                        name = it["name"] as? String ?: "Device $pylonDeviceId",
                        icon = it["icon"] as? String ?: "💻",
                        role = it["role"] as? String ?: "unknown",
                        connectedAt = ""
                    )
                }

                val desksList = (payload["desks"] as? List<*>)?.mapNotNull { desk ->
                    (desk as? Map<*, *>)?.let {
                        DeskInfo(
                            deviceId = pylonDeviceId,
                            deviceName = deviceInfo?.name ?: "Device $pylonDeviceId",
                            deviceIcon = deviceInfo?.icon ?: "💻",
                            deskId = it["deskId"] as? String ?: "",
                            deskName = (it["name"] ?: it["deskName"]) as? String ?: "",
                            workingDir = it["workingDir"] as? String ?: "",
                            status = it["status"] as? String ?: "idle",
                            isActive = it["isActive"] as? Boolean ?: false
                        )
                    }
                } ?: emptyList()

                _pylonDesks.value = _pylonDesks.value + (pylonDeviceId to Pair(deviceInfo, desksList))
                updateAllDesks()

                // 선택된 데스크가 없으면 첫 번째 활성 데스크 선택
                if (_selectedDesk.value == null) {
                    _selectedDesk.value = allDesks.value.find { it.isActive && it.status != "offline" }
                        ?: allDesks.value.firstOrNull()
                }
            }

            // 데스크 상태 업데이트
            "desk_status" -> {
                val payload = data["payload"] as? Map<*, *> ?: return
                val pylonDeviceId = (payload["deviceId"] as? Number)?.toInt() ?: return
                val deskId = payload["deskId"] as? String ?: return
                val status = payload["status"] as? String
                val isActive = payload["isActive"] as? Boolean

                val current = _pylonDesks.value[pylonDeviceId] ?: return
                val updatedDesks = current.second.map { desk ->
                    if (desk.deskId == deskId) {
                        desk.copy(
                            status = status ?: desk.status,
                            isActive = isActive ?: desk.isActive
                        )
                    } else desk
                }
                _pylonDesks.value = _pylonDesks.value + (pylonDeviceId to Pair(current.first, updatedDesks))
                updateAllDesks()
            }

            // Claude 이벤트
            "claude_event" -> {
                val payload = data["payload"] as? Map<*, *> ?: return
                val deskId = payload["deskId"] as? String ?: return
                val event = payload["event"] as? Map<*, *> ?: return

                handleClaudeEvent(deskId, event)
            }

            // 에러
            "error" -> {
                val payload = data["payload"] as? Map<*, *>
                val error = payload?.get("error") as? String ?: "Unknown error"
                // 에러 메시지 추가
                _selectedDesk.value?.let { desk ->
                    addClaudeMessage(desk.deskId, false, "❌ Error: $error", ClaudeEvent.Error(error))
                }
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleClaudeEvent(deskId: String, eventData: Map<*, *>) {
        val eventType = eventData["type"] as? String ?: return

        when (eventType) {
            "text" -> {
                val content = eventData["content"] as? String ?: ""
                _currentTextBuffer.value += content
            }

            "tool_start" -> {
                flushTextBuffer(deskId)
                val event = ClaudeEvent.ToolStart(
                    toolName = eventData["toolName"] as? String ?: "",
                    toolInput = eventData["toolInput"] as? Map<String, Any?> ?: emptyMap(),
                    toolUseId = eventData["toolUseId"] as? String ?: ""
                )
                addClaudeMessage(deskId, false, "🔧 ${event.toolName}", event)
            }

            "tool_complete" -> {
                val event = ClaudeEvent.ToolComplete(
                    toolUseId = eventData["toolUseId"] as? String ?: "",
                    output = eventData["output"]
                )
                // 기존 tool_start 메시지 업데이트
                val toolUseId = event.toolUseId
                _claudeMessages.value = _claudeMessages.value.map { msg ->
                    if (msg.event is ClaudeEvent.ToolStart && msg.event.toolUseId == toolUseId) {
                        msg.copy(content = "✅ ${msg.event.toolName}", event = event)
                    } else msg
                }
            }

            "permission_request" -> {
                flushTextBuffer(deskId)
                val event = ClaudeEvent.PermissionRequest(
                    toolName = eventData["toolName"] as? String ?: "",
                    toolInput = eventData["toolInput"] as? Map<String, Any?> ?: emptyMap(),
                    toolUseId = eventData["toolUseId"] as? String ?: ""
                )
                _pendingPermission.value = event
                _claudeState.value = "permission"
                addClaudeMessage(deskId, false, "⚠️ Permission: ${event.toolName}", event)
            }

            "ask_question" -> {
                flushTextBuffer(deskId)
                val event = ClaudeEvent.AskQuestion(
                    question = eventData["question"] as? String ?: "",
                    options = (eventData["options"] as? List<*>)?.mapNotNull { it as? String } ?: emptyList(),
                    toolUseId = eventData["toolUseId"] as? String ?: ""
                )
                _pendingQuestion.value = event
            }

            "state" -> {
                val state = eventData["state"] as? String ?: ""
                _claudeState.value = state
                if (state == "idle") {
                    flushTextBuffer(deskId)
                }
            }

            "result" -> {
                flushTextBuffer(deskId)
            }

            "error" -> {
                flushTextBuffer(deskId)
                val error = eventData["error"] as? String ?: "Unknown error"
                _claudeState.value = "idle"
                addClaudeMessage(deskId, false, "❌ Error: $error", ClaudeEvent.Error(error))
            }
        }
    }

    private fun flushTextBuffer(deskId: String) {
        val text = _currentTextBuffer.value.trim()
        if (text.isNotEmpty()) {
            addClaudeMessage(deskId, false, text)
            _currentTextBuffer.value = ""
        }
    }

    private fun addClaudeMessage(deskId: String, isUser: Boolean, content: String, event: ClaudeEvent? = null) {
        val message = ClaudeMessage(
            id = "${System.currentTimeMillis()}-${_claudeMessages.value.size}",
            deskId = deskId,
            isUser = isUser,
            content = content,
            timestamp = System.currentTimeMillis(),
            event = event
        )
        _claudeMessages.value = (_claudeMessages.value + message).takeLast(500)
    }

    // ============ Public API ============

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
            apkFile?.let { updateChecker.installApk(it) }
        }
    }

    // ============ 데스크 & Claude API ============

    fun selectDesk(desk: DeskInfo) {
        _selectedDesk.value = desk
        _claudeMessages.value = emptyList()
        _currentTextBuffer.value = ""
    }

    fun sendToSelectedDesk(message: String) {
        val desk = _selectedDesk.value ?: return
        addClaudeMessage(desk.deskId, true, message)
        relayClient.sendClaudeMessage(desk.deviceId, desk.deskId, message)
        _claudeState.value = "working"
    }

    fun respondPermission(decision: String) {
        val desk = _selectedDesk.value ?: return
        val perm = _pendingPermission.value ?: return
        relayClient.sendClaudePermission(desk.deviceId, desk.deskId, perm.toolUseId, decision)
        _pendingPermission.value = null
        _claudeState.value = "working"
    }

    fun respondQuestion(answer: String) {
        val desk = _selectedDesk.value ?: return
        val q = _pendingQuestion.value ?: return
        relayClient.sendClaudeAnswer(desk.deviceId, desk.deskId, q.toolUseId, answer)
        _pendingQuestion.value = null
    }

    fun stopClaude() {
        val desk = _selectedDesk.value ?: return
        relayClient.sendClaudeControl(desk.deviceId, desk.deskId, "stop")
    }

    fun newSession() {
        val desk = _selectedDesk.value ?: return
        relayClient.sendClaudeControl(desk.deviceId, desk.deskId, "new_session")
        _claudeMessages.value = emptyList()
        _currentTextBuffer.value = ""
    }

    override fun onCleared() {
        super.onCleared()
        relayClient.disconnect()
    }
}
