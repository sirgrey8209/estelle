# estelle-mobile - 구현 계획

## 역할

안드로이드 네이티브 앱
- Relay에 직접 WebSocket 연결
- 모바일 사용자 인터페이스 제공

## Phase 1 목표

- Android 프로젝트 기본 구조
- Relay에 WebSocket 연결
- 연결 상태 표시 UI
- 간단한 에코 테스트 UI

## 기술 스택

- Kotlin
- OkHttp (WebSocket)
- Jetpack Compose (UI)
- Coroutines (비동기)

## 폴더 구조

```
estelle-mobile/
├── PLAN.md
├── app/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/estelle/
│       │   ├── MainActivity.kt
│       │   ├── EstelleApp.kt
│       │   └── network/
│       │       └── RelayClient.kt
│       └── res/
│           └── ...
├── build.gradle.kts
└── settings.gradle.kts
```

## 구현 상세

### 1. WebSocket 연결 (RelayClient.kt)
```kotlin
class RelayClient {
    private val client = OkHttpClient()
    private var webSocket: WebSocket? = null

    fun connect(url: String, listener: WebSocketListener) {
        val request = Request.Builder().url(url).build()
        webSocket = client.newWebSocket(request, listener)
    }

    fun send(message: String) {
        webSocket?.send(message)
    }

    fun disconnect() {
        webSocket?.close(1000, "Goodbye")
    }
}
```

### 2. UI (MainActivity.kt with Compose)
```kotlin
@Composable
fun NexusScreen(viewModel: MainViewModel) {
    val connected by viewModel.connected.collectAsState()
    val response by viewModel.response.collectAsState()
    var message by remember { mutableStateOf("") }

    Column {
        Text("Estelle")
        Text(if (connected) "🟢 Connected" else "🔴 Disconnected")

        TextField(
            value = message,
            onValueChange = { message = it }
        )
        Button(onClick = { viewModel.send(message) }) {
            Text("Send")
        }

        Text("Response: $response")
    }
}
```

### 3. 권한 (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## UI 구성 (Phase 1)

```
┌─────────────────────────────────┐
│ Estelle                           │
├─────────────────────────────────┤
│                                 │
│  Relay: 🟢 Connected            │
│                                 │
│  ┌─────────────────────────┐    │
│  │ Hello                   │    │
│  └─────────────────────────┘    │
│                                 │
│  ┌─────────────────────────┐    │
│  │         Send            │    │
│  └─────────────────────────┘    │
│                                 │
│  Response: Hello                │
│                                 │
└─────────────────────────────────┘
```

## 테스트 방법

```bash
# Relay 먼저 실행 (로컬 또는 Fly.io)
# Android Studio에서 앱 실행
# 연결 상태 확인
# Send 버튼으로 에코 테스트
```

## 환경 설정

```kotlin
// 개발용
const val RELAY_URL = "ws://[집PC IP]:8080"

// 프로덕션
const val RELAY_URL = "wss://estelle-relay.fly.dev"
```

## 다음 단계 (Phase 2)

- 메시징 UI
- 태스크 보드 UI
- 파일 뷰어
- 푸시 알림 (FCM)
- 백그라운드 연결 유지
