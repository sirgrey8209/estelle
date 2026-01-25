# App 개요

> Flutter 기반 통합 클라이언트 앱

## 기본 정보

| 항목 | 값 |
|------|-----|
| 플랫폼 | Windows, Android, Web |
| 프레임워크 | Flutter |
| 상태관리 | Riverpod |
| 최소 SDK | Flutter 3.x |

---

## 폴더 구조

```
lib/
├── main.dart                      # 앱 진입점
├── app.dart                       # EstelleApp (MaterialApp)
│
├── core/                          # 공통 유틸리티
│   ├── constants/
│   │   ├── colors.dart            # 색상 상수
│   │   ├── relay_config.dart      # Relay URL 설정
│   │   └── build_info.dart        # 빌드 정보
│   ├── theme/
│   │   ├── app_theme.dart         # 테마 설정
│   │   └── app_colors.dart        # 테마 색상
│   └── utils/
│       └── responsive_utils.dart  # 반응형 유틸
│
├── data/                          # 데이터 레이어
│   ├── models/
│   │   ├── claude_message.dart    # 메시지 모델
│   │   ├── claude_usage.dart      # 사용량 모델
│   │   ├── deploy_status.dart     # 배포 상태 모델
│   │   ├── pending_request.dart   # 권한/질문 요청 모델
│   │   └── workspace_info.dart    # 워크스페이스 모델
│   └── services/
│       └── relay_service.dart     # Relay WebSocket 서비스
│
├── state/                         # 상태 관리
│   └── providers/
│       ├── relay_provider.dart    # Relay 연결 상태
│       ├── workspace_provider.dart # 워크스페이스 상태
│       ├── claude_provider.dart   # Claude 메시지 상태
│       └── settings_provider.dart # 설정 상태
│
└── ui/                            # UI 레이어
    ├── layouts/
    │   ├── responsive_layout.dart # 반응형 분기
    │   ├── desktop_layout.dart    # 데스크탑 레이아웃
    │   └── mobile_layout.dart     # 모바일 레이아웃
    │
    └── widgets/
        ├── chat/                  # 채팅 관련
        │   ├── chat_area.dart
        │   ├── message_list.dart
        │   ├── message_bubble.dart
        │   ├── streaming_bubble.dart
        │   ├── tool_card.dart
        │   ├── result_info.dart
        │   ├── working_indicator.dart
        │   └── input_bar.dart
        │
        ├── sidebar/               # 사이드바
        │   ├── workspace_sidebar.dart
        │   ├── workspace_item.dart
        │   └── new_workspace_dialog.dart
        │
        ├── requests/              # 권한/질문 요청
        │   ├── request_bar.dart
        │   ├── permission_request_view.dart
        │   └── question_request_view.dart
        │
        ├── settings/              # 설정
        │   ├── settings_screen.dart
        │   ├── settings_dialog.dart
        │   ├── permission_mode_section.dart
        │   ├── deploy_section.dart
        │   ├── deploy_status_card.dart
        │   ├── app_update_section.dart
        │   └── claude_usage_card.dart
        │
        ├── deploy/
        │   └── deploy_dialog.dart
        │
        ├── task/
        │   └── task_detail_view.dart
        │
        └── common/
            ├── loading_overlay.dart
            └── bug_report_dialog.dart
```

---

## 앱 시작 흐름

```
main.dart
  │
  ├── WidgetsFlutterBinding.ensureInitialized()
  ├── URL 파라미터 확인 (Web: ?mobile=true)
  │
  └── ProviderScope
        └── EstelleApp
              │
              ├── initState: Relay 연결 시작
              │     └── ref.read(relayServiceProvider).connect()
              │
              └── build: MaterialApp
                    │
                    ├── theme: AppTheme.darkTheme
                    │
                    └── home: ResponsiveLayout
                          │
                          ├── Desktop (>=600px): DesktopLayout
                          └── Mobile (<600px): MobileLayout
```

---

## 상태 관리 구조

### Provider 의존성

```
relayServiceProvider
      │
      ├── authStateProvider (AsyncValue<bool>)
      │     └── 인증 상태 (인증 완료 시 워크스페이스 목록 요청)
      │
      ├── pylonWorkspacesProvider
      │     └── Map<deviceId, PylonWorkspaces>
      │
      ├── selectedItemProvider
      │     └── SelectedItem? (현재 선택된 워크스페이스/대화)
      │
      └── claudeMessagesProvider
            └── List<ClaudeMessage>
```

### 주요 Provider

| Provider | 타입 | 역할 |
|----------|------|------|
| `relayServiceProvider` | `RelayService` | WebSocket 연결 관리 |
| `authStateProvider` | `AsyncValue<bool>` | 인증 상태 |
| `pylonWorkspacesProvider` | `Map<int, PylonWorkspaces>` | Pylon별 워크스페이스 목록 |
| `selectedItemProvider` | `SelectedItem?` | 현재 선택된 항목 |
| `claudeMessagesProvider` | `List<ClaudeMessage>` | 현재 대화 메시지 목록 |
| `claudeStateProvider` | `String` | Claude 상태 (idle/working/permission) |
| `pendingRequestsProvider` | `List<PendingRequest>` | 대기 중인 권한/질문 요청 |
| `currentTextBufferProvider` | `String` | 스트리밍 텍스트 버퍼 |
| `isThinkingProvider` | `bool` | 생각 중 인디케이터 표시 |

---

## 메시지 타입

`ClaudeMessage` sealed class의 구현체:

| 타입 | 설명 |
|------|------|
| `UserTextMessage` | 사용자 입력 메시지 |
| `AssistantTextMessage` | Claude 응답 텍스트 |
| `ToolCallMessage` | 도구 실행 (시작/완료) |
| `ResultInfoMessage` | 결과 정보 (토큰, 시간) |
| `ErrorMessage` | 에러 메시지 |
| `UserResponseMessage` | 사용자 응답 (권한/질문) |

---

## 반응형 레이아웃

### 분기 기준

```dart
// ResponsiveUtils
static bool shouldShowSidebar(BuildContext context) {
  if (forceMobileLayout) return false;
  return MediaQuery.of(context).size.width >= 600;
}
```

### 레이아웃 구성

#### Desktop (>=600px)

```
┌─────────────────────────────────────────────────┐
│  ┌────────────┐  ┌────────────────────────────┐ │
│  │            │  │                            │ │
│  │  Sidebar   │  │        ChatArea            │ │
│  │  (260px)   │  │                            │ │
│  │            │  │                            │ │
│  │ Workspaces │  │  MessageList               │ │
│  │ + Tasks    │  │  + InputBar                │ │
│  │            │  │  + RequestBar              │ │
│  │            │  │                            │ │
│  └────────────┘  └────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

#### Mobile (<600px)

```
┌─────────────────────┐
│     PageView        │
│                     │
│  ┌────┐    ┌────┐   │
│  │    │    │    │   │
│  │ WS │ ←→ │Chat│   │
│  │List│    │Area│   │
│  │    │    │    │   │
│  └────┘    └────┘   │
│                     │
│  [스와이프로 전환]   │
└─────────────────────┘
```

---

## 연결 관리

### Relay 연결

```dart
class RelayService {
  // Relay URL (fly.io)
  final String relayUrl = 'wss://estelle-relay.fly.dev';

  // 연결 상태
  bool _isConnected = false;
  bool _isAuthenticated = false;

  // WebSocket 채널
  WebSocketChannel? _channel;

  // 메시지 스트림
  Stream<Map<String, dynamic>> get messageStream => _controller.stream;
}
```

### 연결 흐름

```
1. connect()
   └── WebSocketChannel.connect(relayUrl)

2. _onConnected
   └── 'connected' 메시지 수신

3. _sendAuth()
   └── { type: 'auth', payload: { deviceType: 'app' } }

4. auth_result 수신
   └── deviceId 할당 (100+)
   └── authStateProvider = true

5. workspace_list 요청
   └── { type: 'workspace_list', broadcast: 'pylons' }

6. workspace_list_result 수신
   └── pylonWorkspacesProvider 업데이트
```

---

## 관련 문서

### 레이아웃
- [layout/responsive.md](./layout/responsive.md)
- [layout/desktop.md](./layout/desktop.md)
- [layout/mobile.md](./layout/mobile.md)

### 컴포넌트
- [components/tool-card.md](./components/tool-card.md)
- [components/message-bubble.md](./components/message-bubble.md)
- [components/input-bar.md](./components/input-bar.md)
- [components/workspace-sidebar.md](./components/workspace-sidebar.md)

### 상태관리
- [state/workspace-provider.md](./state/workspace-provider.md)
- [state/claude-provider.md](./state/claude-provider.md)
- [state/relay-provider.md](./state/relay-provider.md)
