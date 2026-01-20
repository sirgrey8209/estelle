package com.nexus.android

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class RelayClient(private val url: String, private val deviceId: String) {
    private var webSocket: WebSocket? = null
    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(30, TimeUnit.SECONDS)
        .build()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _messages = MutableStateFlow<List<String>>(emptyList())
    val messages: StateFlow<List<String>> = _messages

    private var onDataCallback: ((Map<String, Any?>) -> Unit)? = null

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
                addMessage("Connected to Estelle Relay")

                // 디바이스 등록
                val identify = JSONObject().apply {
                    put("type", "identify")
                    put("deviceId", deviceId)
                    put("deviceType", "mobile")
                }
                webSocket.send(identify.toString())

                // 디바이스 목록 요청
                val getDevices = JSONObject().apply {
                    put("type", "getDevices")
                }
                webSocket.send(getDevices.toString())
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    val json = JSONObject(text)
                    val data = jsonToMap(json)
                    onDataCallback?.invoke(data)

                    // 채팅 메시지가 아닌 경우만 로그에 추가
                    if (json.optString("type") != "chat") {
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

    fun sendChat(message: String) {
        val json = JSONObject().apply {
            put("type", "chat")
            put("message", message)
        }
        webSocket?.send(json.toString())
    }

    fun send(message: String) {
        val json = JSONObject().apply {
            put("type", "echo")
            put("from", deviceId)
            put("payload", message)
        }
        webSocket?.send(json.toString())
        addMessage("Sent: $message")
    }

    fun sendPing() {
        val json = JSONObject().apply {
            put("type", "ping")
        }
        webSocket?.send(json.toString())
        addMessage("Sent ping")
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
