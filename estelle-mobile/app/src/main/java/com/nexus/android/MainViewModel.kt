package com.nexus.android

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

// ============ 데이터 클래스 ============

data class ConnectedDevice(
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
    data class TextComplete(val text: String) : ClaudeEvent()
    data class ToolStart(val toolName: String, val toolInput: Map<String, Any?>) : ClaudeEvent()
    data class ToolComplete(val toolName: String, val success: Boolean, val output: String?, val error: String?) : ClaudeEvent()
    data class PermissionRequest(val toolName: String, val toolInput: Map<String, Any?>, val toolUseId: String) : ClaudeEvent()
    data class AskQuestion(
        val questions: List<QuestionItem>,
        val toolUseId: String
    ) : ClaudeEvent()
    data class State(val state: String) : ClaudeEvent()
    data class Result(val durationMs: Long, val inputTokens: Int, val outputTokens: Int) : ClaudeEvent()
    data class Error(val error: String) : ClaudeEvent()
}

data class QuestionItem(
    val question: String,
    val header: String,
    val options: List<String>,
    val multiSelect: Boolean
)

// Claude 메시지 (UI용)
sealed class ClaudeMessage {
    abstract val id: String
    abstract val timestamp: Long

    data class UserText(
        override val id: String,
        val content: String,
        override val timestamp: Long
    ) : ClaudeMessage()

    data class AssistantText(
        override val id: String,
        val content: String,
        override val timestamp: Long
    ) : ClaudeMessage()

    data class ToolCall(
        override val id: String,
        val toolName: String,
        val toolInput: Map<String, Any?>,
        val isComplete: Boolean,
        val success: Boolean?,
        val output: String?,
        val error: String?,
        override val timestamp: Long
    ) : ClaudeMessage()

    data class ResultInfo(
        override val id: String,
        val durationMs: Long,
        val inputTokens: Int,
        val outputTokens: Int,
        override val timestamp: Long
    ) : ClaudeMessage()

    data class ErrorMessage(
        override val id: String,
        val error: String,
        override val timestamp: Long
    ) : ClaudeMessage()

    data class UserResponse(
        override val id: String,
        val responseType: String,  // "permission" or "question"
        val content: String,
        override val timestamp: Long
    ) : ClaudeMessage()
}

// 대기 중인 요청
sealed class PendingRequest {
    abstract val toolUseId: String

    data class Permission(
        override val toolUseId: String,
        val toolName: String,
        val toolInput: Map<String, Any?>
    ) : PendingRequest()

    data class Question(
        override val toolUseId: String,
        val questions: List<QuestionItem>,
        val answers: MutableMap<Int, String> = mutableMapOf()
    ) : PendingRequest()
}

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

    private val _devices = MutableStateFlow<List<ConnectedDevice>>(emptyList())
    val devices: StateFlow<List<ConnectedDevice>> = _devices

    private val _chatMessages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val chatMessages: StateFlow<List<ChatMessage>> = _chatMessages

    private val _updateInfo = MutableStateFlow<UpdateChecker.UpdateInfo?>(null)
    val updateInfo: StateFlow<UpdateChecker.UpdateInfo?> = _updateInfo

    private val _downloadProgress = MutableStateFlow(-1)
    val downloadProgress: StateFlow<Int> = _downloadProgress

    // ============ 데스크 & Claude ============

    // deviceId -> (deviceInfo, desks)
    private val _pylonDesks = MutableStateFlow<Map<Int, Pair<ConnectedDevice?, List<DeskInfo>>>>(emptyMap())

    private val _selectedDesk = MutableStateFlow<DeskInfo?>(null)
    val selectedDesk: StateFlow<DeskInfo?> = _selectedDesk

    private val _claudeMessages = MutableStateFlow<List<ClaudeMessage>>(emptyList())
    val claudeMessages: StateFlow<List<ClaudeMessage>> = _claudeMessages

    private val _currentTextBuffer = MutableStateFlow("")
    val currentTextBuffer: StateFlow<String> = _currentTextBuffer

    private val _pendingRequests = MutableStateFlow<List<PendingRequest>>(emptyList())
    val pendingRequests: StateFlow<List<PendingRequest>> = _pendingRequests

    private val _claudeState = MutableStateFlow("idle")
    val claudeState: StateFlow<String> = _claudeState

    private val _isThinking = MutableStateFlow(false)
    val isThinking: StateFlow<Boolean> = _isThinking

    // 모든 데스크 목록 (모든 Pylon에서)
    private val _allDesks = MutableStateFlow<List<DeskInfo>>(emptyList())
    val allDesks: StateFlow<List<DeskInfo>> = _allDesks

    // 데스크별 메시지/요청 저장소
    private val deskMessagesMap = mutableMapOf<String, List<ClaudeMessage>>()
    private val deskRequestsMap = mutableMapOf<String, List<PendingRequest>>()

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
        _allDesks.value = desks
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleRelayMessage(data: Map<String, Any?>) {
        when (data["type"]) {
            // 디바이스 상태
            "device_status" -> {
                val payload = data["payload"] as? Map<*, *> ?: return
                val devicesList = (payload["devices"] as? List<*>)?.mapNotNull { device ->
                    (device as? Map<*, *>)?.let {
                        ConnectedDevice(
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
                    ConnectedDevice(
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
                    _selectedDesk.value = _allDesks.value.find { it.isActive && it.status != "offline" }
                        ?: _allDesks.value.firstOrNull()
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

                // 선택된 데스크 상태도 업데이트
                _selectedDesk.value?.let { selected ->
                    if (selected.deskId == deskId) {
                        _selectedDesk.value = selected.copy(
                            status = status ?: selected.status,
                            isActive = isActive ?: selected.isActive
                        )
                    }
                }
            }

            // Claude 이벤트
            "claude_event" -> {
                val payload = data["payload"] as? Map<*, *> ?: return
                val deskId = payload["deskId"] as? String ?: return
                val event = payload["event"] as? Map<*, *> ?: return

                // 현재 선택된 데스크의 이벤트만 화면에 표시
                if (_selectedDesk.value?.deskId == deskId) {
                    handleClaudeEvent(deskId, event)
                } else {
                    // 다른 데스크의 이벤트는 저장만
                    saveEventForDesk(deskId, event)
                }
            }

            // 에러
            "error" -> {
                val payload = data["payload"] as? Map<*, *>
                val error = payload?.get("error") as? String ?: "Unknown error"
                _selectedDesk.value?.let { desk ->
                    addClaudeMessage(ClaudeMessage.ErrorMessage(
                        id = "${System.currentTimeMillis()}",
                        error = error,
                        timestamp = System.currentTimeMillis()
                    ))
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

            "textComplete" -> {
                _currentTextBuffer.value = ""
                val text = eventData["text"] as? String ?: return
                addClaudeMessage(ClaudeMessage.AssistantText(
                    id = "${System.currentTimeMillis()}",
                    content = text,
                    timestamp = System.currentTimeMillis()
                ))
            }

            "stateUpdate" -> {
                val state = eventData["state"] as? Map<*, *>
                val stateType = state?.get("type") as? String
                _isThinking.value = stateType == "thinking"
            }

            "toolInfo" -> {
                flushTextBuffer()
                val toolName = eventData["toolName"] as? String ?: ""
                val toolInput = eventData["input"] as? Map<String, Any?> ?: emptyMap()
                addClaudeMessage(ClaudeMessage.ToolCall(
                    id = "${System.currentTimeMillis()}-$toolName",
                    toolName = toolName,
                    toolInput = toolInput,
                    isComplete = false,
                    success = null,
                    output = null,
                    error = null,
                    timestamp = System.currentTimeMillis()
                ))
            }

            "toolComplete" -> {
                val toolName = eventData["toolName"] as? String ?: ""
                val success = eventData["success"] as? Boolean ?: true
                val result = eventData["result"] as? String
                val error = eventData["error"] as? String

                // 기존 tool_start 메시지 업데이트
                _claudeMessages.value = _claudeMessages.value.map { msg ->
                    if (msg is ClaudeMessage.ToolCall && msg.toolName == toolName && !msg.isComplete) {
                        msg.copy(isComplete = true, success = success, output = result, error = error)
                    } else msg
                }
            }

            "permission_request" -> {
                flushTextBuffer()
                val toolName = eventData["toolName"] as? String ?: ""
                val toolInput = eventData["toolInput"] as? Map<String, Any?> ?: emptyMap()
                val toolUseId = eventData["toolUseId"] as? String ?: ""

                _pendingRequests.value = _pendingRequests.value + PendingRequest.Permission(
                    toolUseId = toolUseId,
                    toolName = toolName,
                    toolInput = toolInput
                )
                _claudeState.value = "permission"
            }

            "askQuestion" -> {
                flushTextBuffer()
                val questionsRaw = eventData["questions"] as? List<*> ?: return
                val toolUseId = eventData["toolUseId"] as? String ?: ""

                val questions = questionsRaw.mapNotNull { q ->
                    (q as? Map<*, *>)?.let {
                        val optionsRaw = it["options"] as? List<*>
                        QuestionItem(
                            question = it["question"] as? String ?: "",
                            header = it["header"] as? String ?: "Question",
                            options = optionsRaw?.mapNotNull { opt ->
                                (opt as? Map<*, *>)?.get("label") as? String
                            } ?: emptyList(),
                            multiSelect = it["multiSelect"] as? Boolean ?: false
                        )
                    }
                }

                if (questions.isNotEmpty()) {
                    _pendingRequests.value = _pendingRequests.value + PendingRequest.Question(
                        toolUseId = toolUseId,
                        questions = questions
                    )
                    _claudeState.value = "permission"
                }
            }

            "state" -> {
                val state = eventData["state"] as? String ?: ""
                _claudeState.value = state
                if (state == "idle") {
                    flushTextBuffer()
                    _isThinking.value = false
                }
            }

            "result" -> {
                flushTextBuffer()
                val durationMs = (eventData["duration_ms"] as? Number)?.toLong() ?: 0L
                val usage = eventData["usage"] as? Map<*, *>
                val inputTokens = (usage?.get("inputTokens") as? Number)?.toInt() ?: 0
                val outputTokens = (usage?.get("outputTokens") as? Number)?.toInt() ?: 0

                addClaudeMessage(ClaudeMessage.ResultInfo(
                    id = "${System.currentTimeMillis()}-result",
                    durationMs = durationMs,
                    inputTokens = inputTokens,
                    outputTokens = outputTokens,
                    timestamp = System.currentTimeMillis()
                ))
                _isThinking.value = false
            }

            "error" -> {
                flushTextBuffer()
                val error = eventData["error"] as? String ?: "Unknown error"
                _claudeState.value = "idle"
                _isThinking.value = false
                addClaudeMessage(ClaudeMessage.ErrorMessage(
                    id = "${System.currentTimeMillis()}-error",
                    error = error,
                    timestamp = System.currentTimeMillis()
                ))
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun saveEventForDesk(deskId: String, eventData: Map<*, *>) {
        val eventType = eventData["type"] as? String ?: return

        when (eventType) {
            "textComplete" -> {
                val text = eventData["text"] as? String ?: return
                val saved = deskMessagesMap[deskId]?.toMutableList() ?: mutableListOf()
                saved.add(ClaudeMessage.AssistantText(
                    id = "${System.currentTimeMillis()}",
                    content = text,
                    timestamp = System.currentTimeMillis()
                ))
                deskMessagesMap[deskId] = saved
            }
            "error" -> {
                val error = eventData["error"] as? String ?: "Unknown error"
                val saved = deskMessagesMap[deskId]?.toMutableList() ?: mutableListOf()
                saved.add(ClaudeMessage.ErrorMessage(
                    id = "${System.currentTimeMillis()}-error",
                    error = error,
                    timestamp = System.currentTimeMillis()
                ))
                deskMessagesMap[deskId] = saved
            }
            "permission_request", "askQuestion" -> {
                // 다른 데스크의 요청도 저장
                val savedRequests = deskRequestsMap[deskId]?.toMutableList() ?: mutableListOf()
                if (eventType == "permission_request") {
                    savedRequests.add(PendingRequest.Permission(
                        toolUseId = eventData["toolUseId"] as? String ?: "",
                        toolName = eventData["toolName"] as? String ?: "",
                        toolInput = eventData["toolInput"] as? Map<String, Any?> ?: emptyMap()
                    ))
                }
                deskRequestsMap[deskId] = savedRequests
            }
        }
    }

    private fun flushTextBuffer() {
        val text = _currentTextBuffer.value.trim()
        if (text.isNotEmpty()) {
            addClaudeMessage(ClaudeMessage.AssistantText(
                id = "${System.currentTimeMillis()}-buffer",
                content = text,
                timestamp = System.currentTimeMillis()
            ))
            _currentTextBuffer.value = ""
        }
    }

    private fun addClaudeMessage(message: ClaudeMessage) {
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
        // 현재 데스크의 메시지와 요청 저장
        _selectedDesk.value?.let { current ->
            deskMessagesMap[current.deskId] = _claudeMessages.value
            if (_pendingRequests.value.isNotEmpty()) {
                deskRequestsMap[current.deskId] = _pendingRequests.value
            } else {
                deskRequestsMap.remove(current.deskId)
            }
        }

        // 새 데스크 선택
        _selectedDesk.value = desk

        // 저장된 메시지와 요청 복원
        _claudeMessages.value = deskMessagesMap[desk.deskId] ?: emptyList()
        _pendingRequests.value = deskRequestsMap[desk.deskId] ?: emptyList()
        _currentTextBuffer.value = ""
        _claudeState.value = if (_pendingRequests.value.isNotEmpty()) "permission" else "idle"
        _isThinking.value = false
    }

    fun sendToSelectedDesk(message: String) {
        val desk = _selectedDesk.value ?: return

        // 사용자 메시지 추가
        addClaudeMessage(ClaudeMessage.UserText(
            id = "${System.currentTimeMillis()}-user",
            content = message,
            timestamp = System.currentTimeMillis()
        ))

        relayClient.sendClaudeMessage(desk.deviceId, desk.deskId, message)
        _claudeState.value = "working"
        _isThinking.value = true
    }

    fun respondPermission(decision: String) {
        val desk = _selectedDesk.value ?: return
        val request = _pendingRequests.value.firstOrNull() as? PendingRequest.Permission ?: return

        // 응답 기록
        val decisionText = if (decision == "allow") "승인됨" else "거부됨"
        addClaudeMessage(ClaudeMessage.UserResponse(
            id = "${System.currentTimeMillis()}-response",
            responseType = "permission",
            content = "${request.toolName} ($decisionText)",
            timestamp = System.currentTimeMillis()
        ))

        relayClient.sendClaudePermission(desk.deviceId, desk.deskId, request.toolUseId, decision)

        // 요청 제거
        _pendingRequests.value = _pendingRequests.value.drop(1)
        if (_pendingRequests.value.isEmpty()) {
            _claudeState.value = "working"
        }
    }

    fun respondQuestion(answer: String) {
        val desk = _selectedDesk.value ?: return
        val request = _pendingRequests.value.firstOrNull() as? PendingRequest.Question ?: return

        // 응답 기록
        addClaudeMessage(ClaudeMessage.UserResponse(
            id = "${System.currentTimeMillis()}-response",
            responseType = "question",
            content = answer,
            timestamp = System.currentTimeMillis()
        ))

        relayClient.sendClaudeAnswer(desk.deviceId, desk.deskId, request.toolUseId, answer)

        // 요청 제거
        _pendingRequests.value = _pendingRequests.value.drop(1)
        deskRequestsMap.remove(desk.deskId)
        if (_pendingRequests.value.isEmpty()) {
            _claudeState.value = "working"
        }
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
        _pendingRequests.value = emptyList()
        _claudeState.value = "idle"
        deskMessagesMap.remove(desk.deskId)
        deskRequestsMap.remove(desk.deskId)
    }

    override fun onCleared() {
        super.onCleared()
        relayClient.disconnect()
    }
}
