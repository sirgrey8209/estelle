package com.nexus.android

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.StateFlow

class MainViewModel : ViewModel() {
    // 개발 중에는 로컬 IP 사용, 프로덕션에서는 Fly.io URL 사용
    private val relayUrl = "ws://10.0.2.2:8080" // 에뮬레이터에서 호스트 PC 접근
    // private val relayUrl = "wss://nexus-relay.fly.dev" // 프로덕션

    private val relayClient = RelayClient(relayUrl)

    val isConnected: StateFlow<Boolean> = relayClient.isConnected
    val messages: StateFlow<List<String>> = relayClient.messages

    fun connect() {
        relayClient.connect()
    }

    fun disconnect() {
        relayClient.disconnect()
    }

    fun send(message: String) {
        relayClient.send(message)
    }

    fun sendPing() {
        relayClient.sendPing()
    }

    override fun onCleared() {
        super.onCleared()
        relayClient.disconnect()
    }
}
