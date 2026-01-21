package com.nexus.android

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class RelayClient(private val url: String, private val deviceId: Int) {
    private var webSocket: WebSocket? = null
    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(30, TimeUnit.SECONDS)
        .build()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated

    private val _deviceInfo = MutableStateFlow<DeviceInfo?>(null)
    val deviceInfo: StateFlow<DeviceInfo?> = _deviceInfo

    private val _messages = MutableStateFlow<List<String>>(emptyList())
    val messages: StateFlow<List<String>> = _messages

    private var onDataCallback: ((Map<String, Any?>) -> Unit)? = null

    data class DeviceInfo(
        val deviceId: Int,
        val deviceType: String,
        val name: String,
        val icon: String,
        val role: String
    )

    fun setOnDataCallback(callback: (Map<String, Any?>) -> Unit) {
        onDataCallback = callback
    }

    fun connect() {
        val request = Request.Builder()
            .url(url)
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                _isConnected.value = true
                addMessage("Connected to Estelle Relay v1")

                // 인증 요청
                val auth = JSONObject().apply {
                    put("type", "auth")
                    put("payload", JSONObject().apply {
                        put("deviceId", deviceId)
                        put("deviceType", "mobile")
                    })
                }
                webSocket.send(auth.toString())
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    val json = JSONObject(text)
                    val data = jsonToMap(json)

                    // 인증 결과 처리
                    handleAuthResult(json)

                    onDataCallback?.invoke(data)

                    // 로그 (일부 메시지 제외)
                    val type = json.optString("type")
                    if (type != "chat" && type != "claude_event" && type != "device_status") {
                        addMessage("Received: ${text.take(100)}...")
                    }
                } catch (e: Exception) {
                    addMessage("Received: $text")
                }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                _isConnected.value = false
                _isAuthenticated.value = false
                _deviceInfo.value = null
                addMessage("Disconnected from Relay")

                // 재연결 시도
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    if (!_isConnected.value) {
                        connect()
                    }
                }, 3000)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                _isConnected.value = false
                _isAuthenticated.value = false
                _deviceInfo.value = null
                addMessage("Connection error: ${t.message}")

                // 재연결 시도
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    if (!_isConnected.value) {
                        connect()
                    }
                }, 3000)
            }
        })
    }

    private fun handleAuthResult(json: JSONObject) {
        if (json.optString("type") == "auth_result") {
            val payload = json.optJSONObject("payload")
            if (payload?.optBoolean("success") == true) {
                _isAuthenticated.value = true
                val device = payload.optJSONObject("device")
                if (device != null) {
                    _deviceInfo.value = DeviceInfo(
                        deviceId = device.optInt("deviceId"),
                        deviceType = device.optString("deviceType"),
                        name = device.optString("name"),
                        icon = device.optString("icon"),
                        role = device.optString("role")
                    )
                }
                addMessage("Authenticated as ${_deviceInfo.value?.name ?: deviceId}")
            } else {
                addMessage("Auth failed: ${payload?.optString("error")}")
            }
        }
    }

    private fun jsonToMap(json: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        json.keys().forEach { key ->
            val value = json.opt(key)
            map[key] = when (value) {
                is JSONObject -> jsonToMap(value)
                is org.json.JSONArray -> {
                    (0 until value.length()).map { i ->
                        val item = value.opt(i)
                        if (item is JSONObject) jsonToMap(item) else item
                    }
                }
                else -> value
            }
        }
        return map
    }

    // ============ 메시지 전송 ============

    fun send(json: JSONObject) {
        webSocket?.send(json.toString())
    }

    fun sendChat(message: String) {
        val json = JSONObject().apply {
            put("type", "chat")
            put("message", message)
            put("broadcast", "all")
        }
        send(json)
    }

    fun sendPing() {
        val json = JSONObject().apply {
            put("type", "ping")
        }
        send(json)
        addMessage("Sent ping")
    }

    // ============ 데스크 관리 ============

    fun requestDeskList() {
        val json = JSONObject().apply {
            put("type", "desk_list")
            put("broadcast", "pylons")
        }
        send(json)
    }

    fun switchDesk(deviceId: Int, deskId: String) {
        val json = JSONObject().apply {
            put("type", "desk_switch")
            put("to", JSONObject().apply {
                put("deviceId", deviceId)
                put("deviceType", "pylon")
            })
            put("payload", JSONObject().apply {
                put("deskId", deskId)
            })
        }
        send(json)
    }

    // ============ Claude 제어 ============

    fun sendClaudeMessage(targetDeviceId: Int, deskId: String, message: String) {
        val json = JSONObject().apply {
            put("type", "claude_send")
            put("to", JSONObject().apply {
                put("deviceId", targetDeviceId)
                put("deviceType", "pylon")
            })
            put("payload", JSONObject().apply {
                put("deskId", deskId)
                put("message", message)
            })
        }
        send(json)
        addMessage("Sent to Claude: ${message.take(50)}...")
    }

    fun sendClaudePermission(targetDeviceId: Int, deskId: String, toolUseId: String, decision: String) {
        val json = JSONObject().apply {
            put("type", "claude_permission")
            put("to", JSONObject().apply {
                put("deviceId", targetDeviceId)
                put("deviceType", "pylon")
            })
            put("payload", JSONObject().apply {
                put("deskId", deskId)
                put("toolUseId", toolUseId)
                put("decision", decision)
            })
        }
        send(json)
        addMessage("Permission: $decision")
    }

    fun sendClaudeAnswer(targetDeviceId: Int, deskId: String, toolUseId: String, answer: String) {
        val json = JSONObject().apply {
            put("type", "claude_answer")
            put("to", JSONObject().apply {
                put("deviceId", targetDeviceId)
                put("deviceType", "pylon")
            })
            put("payload", JSONObject().apply {
                put("deskId", deskId)
                put("toolUseId", toolUseId)
                put("answer", answer)
            })
        }
        send(json)
    }

    fun sendClaudeControl(targetDeviceId: Int, deskId: String, action: String) {
        val json = JSONObject().apply {
            put("type", "claude_control")
            put("to", JSONObject().apply {
                put("deviceId", targetDeviceId)
                put("deviceType", "pylon")
            })
            put("payload", JSONObject().apply {
                put("deskId", deskId)
                put("action", action)
            })
        }
        send(json)
        addMessage("Claude control: $action")
    }

    fun disconnect() {
        webSocket?.close(1000, "Goodbye")
        webSocket = null
    }

    private fun addMessage(message: String) {
        val timestamp = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
            .format(java.util.Date())
        _messages.value = (_messages.value + "[$timestamp] $message").takeLast(50)
    }

    fun clearMessages() {
        _messages.value = emptyList()
    }
}
