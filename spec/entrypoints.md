# Entrypoints & Component Hierarchy

> 코드 진입점과 컴포넌트 계층 구조

---

## Relay

**진입점**: `estelle-relay/src/index.js`

단일 파일. WebSocket 서버 + 라우팅 로직 전부 포함.

```
index.js
├── DEVICES 상수 (고정 디바이스 정의)
├── authenticateDevice() (인증)
├── sendTo/broadcast() (라우팅)
├── handleMessage() (메시지 핸들러)
└── WebSocket.Server (서버 시작)
```

---

## Pylon

**진입점**: `estelle-pylon/src/index.js`

```
index.js                    # 메인 진입점, 모듈 연결
├── relayClient.js          # Relay WebSocket 연결
├── localServer.js          # 로컬 WebSocket 서버 (9999)
├── claudeManager.js        # Claude SDK 세션 관리 ★ 핵심
├── workspaceStore.js       # 워크스페이스 CRUD
├── messageStore.js         # 대화 메시지 저장/로드
├── taskManager.js          # 태스크 파일 관리
├── workerManager.js        # 워커 프로세스 관리
└── logger.js               # 로깅
```

### 핵심 흐름
```
App 메시지 → relayClient → index.js → claudeManager
                                    → workspaceStore
                                    → messageStore
```

---

## App (Flutter)

**진입점**: `estelle-app/lib/main.dart`

### 폴더 구조
```
lib/
├── main.dart                    # 앱 진입점
├── core/
│   ├── constants/               # 색상, 설정값
│   └── utils/                   # 유틸리티
├── data/
│   ├── models/                  # 데이터 모델
│   └── services/                # RelayService 등
├── state/
│   └── providers/               # Riverpod Provider들
└── ui/
    ├── layouts/                 # 레이아웃 (반응형)
    └── widgets/                 # UI 컴포넌트
```

### Provider 계층
```
ProviderScope (main.dart)
├── relayServiceProvider         # Relay 연결 관리
├── workspaceProvider            # 워크스페이스 목록
├── selectedItemProvider         # 현재 선택된 항목
├── claudeMessagesProvider       # Claude 메시지
├── claudeStateProvider          # Claude 상태 (idle/working)
└── permissionRequestProvider    # 권한 요청
```

### Layout 계층
```
ResponsiveLayout                 # 화면 크기 감지
├── DesktopLayout               # >= 600px
│   ├── WorkspaceSidebar        # 좌측 사이드바
│   └── MainContent             # 우측 메인 영역
│       ├── ChatArea            # 채팅 영역
│       │   ├── MessageList     # 메시지 목록
│       │   │   ├── MessageBubble
│       │   │   ├── ToolCard
│       │   │   └── StreamingBubble
│       │   └── InputBar        # 입력창
│       └── SettingsScreen      # 설정 화면
└── MobileLayout                # < 600px
    └── PageView (3페이지 스와이프)
        ├── WorkspaceSidebar
        ├── ChatArea
        └── SettingsScreen
```

### Widget 계층 (Chat)
```
ChatArea
├── WorkingIndicator            # 작업 중 표시 (상단)
├── MessageList                 # 스크롤 영역
│   └── 각 메시지별:
│       ├── MessageBubble       # user/assistant 텍스트
│       ├── ToolCard            # 도구 실행 결과
│       ├── StreamingBubble     # 스트리밍 중
│       └── ResultInfo          # 완료 시 토큰/시간
├── RequestBar                  # 권한/질문 요청 (하단)
│   ├── PermissionRequestView
│   └── QuestionRequestView
└── InputBar                    # 메시지 입력 (하단)
```

### Widget 계층 (Sidebar)
```
WorkspaceSidebar
├── Header (Relay 상태)
├── WorkspaceItem (각 워크스페이스)
│   ├── 상태 dot (online/offline)
│   └── ConversationItem (각 대화)
└── Footer (버전 정보)
```

---

## 주요 파일 빠른 참조

| 작업 | 파일 |
|------|------|
| Relay 라우팅 수정 | `estelle-relay/src/index.js` |
| Claude 권한 처리 | `estelle-pylon/src/claudeManager.js` |
| 메시지 저장 로직 | `estelle-pylon/src/messageStore.js` |
| Relay 연결 | `estelle-app/lib/data/services/relay_service.dart` |
| 상태 관리 | `estelle-app/lib/state/providers/*.dart` |
| 채팅 UI | `estelle-app/lib/ui/widgets/chat/*.dart` |
| 사이드바 UI | `estelle-app/lib/ui/widgets/sidebar/*.dart` |
| 레이아웃 | `estelle-app/lib/ui/layouts/*.dart` |
| 색상 정의 | `estelle-app/lib/core/constants/colors.dart` |

---

*코드 동작 의도는 각 파일의 주석을 참고하세요.*
