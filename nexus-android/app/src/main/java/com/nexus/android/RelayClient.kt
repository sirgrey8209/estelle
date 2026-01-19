package com.nexus.android

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class RelayClient(private val url: String) {
    private var webSocket: WebSocket? = null
    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _messages = MutableStateFlow<List<String>>(emptyList())
    val messages: StateFlow<List<String>> = _messages

    fun connect() {
        val request = Request.Builder()
            .url(url)
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                _isConnected.value = true
                addMessage("Connected to Relay")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                addMessage("Received: $text")
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                _isConnected.value = false
                addMessage("Disconnected from Relay")
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                _isConnected.value = false
                addMessage("Connection error: ${t.message}")
            }
        })
    }

    fun send(message: String) {
        val json = JSONObject().apply {
            put("type", "echo")
            put("from", "android")
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
