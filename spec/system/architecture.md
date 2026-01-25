# 시스템 아키텍처

> Estelle 시스템의 전체 구조와 통신 흐름

## 시스템 구성도

```
                              ┌─────────────────────┐
                              │   Estelle Relay     │
                              │   (Fly.io 8080)     │
                              │                     │
                              │  - 인증             │
                              │  - 라우팅           │
                              │  - 디바이스 목록    │
                              └──────────┬──────────┘
                                         │
              WebSocket (wss://estelle-relay.fly.dev)
                                         │
         ┌───────────────────────────────┼───────────────────────────────┐
         │                               │                               │
         ▼                               ▼                               ▼
┌─────────────────┐            ┌─────────────────┐            ┌─────────────────┐
│  Pylon (Selene) │            │  Pylon (Stella) │            │      App        │
│  deviceId: 1    │            │  deviceId: 2    │            │  deviceId: 100+ │
│  집 PC          │            │  회사 PC        │            │  Desktop/Mobile │
├─────────────────┤            ├─────────────────┤            ├─────────────────┤
│ - Claude SDK    │            │ - Claude SDK    │            │ - UI 표시       │
│ - 워크스페이스  │            │ - 워크스페이스  │            │ - 메시지 송수신 │
│ - 메시지 저장   │            │ - 메시지 저장   │            │ - 권한 응답     │
│ - 로컬 서버     │            │ - 로컬 서버     │            │                 │
└────────┬────────┘            └────────┬────────┘            └─────────────────┘
         │                              │
    localhost:9000                 localhost:9000
         │                              │
         ▼                              ▼
┌─────────────────┐            ┌─────────────────┐
│ Desktop App     │            │ Desktop App     │
│ (로컬 연결)     │            │ (로컬 연결)     │
└─────────────────┘            └─────────────────┘
```

---

## 컴포넌트 역할

### 1. Relay (estelle-relay)

**역할**: 중앙 라우팅 서버

**특징**:
- 순수 라우터 - 메시지 내용을 해석하지 않음
- `to`, `broadcast` 필드만 보고 라우팅
- Fly.io에 배포 (wss://estelle-relay.fly.dev)

**처리하는 메시지**:
| 타입 | 설명 |
|------|------|
| `auth` | 디바이스 인증 |
| `get_devices` | 연결된 디바이스 목록 |
| `ping` | 연결 확인 |
| `relay_update` | Relay 자체 업데이트 (Pylon만) |
| `relay_version` | Relay 버전 확인 |

**라우팅 규칙**:
| 조건 | 동작 |
|------|------|
| `to: deviceId` | 해당 디바이스로 전송 |
| `to: [deviceId, ...]` | 여러 디바이스로 전송 |
| `broadcast: 'all'` | 모든 인증된 클라이언트 |
| `broadcast: 'pylons'` | 모든 Pylon |
| `broadcast: 'clients'` | Pylon 제외 모든 클라이언트 |
| `broadcast: 'app'` | App 타입 클라이언트만 |
| 기본 (Pylon → ) | 클라이언트들에게 |
| 기본 (클라이언트 → ) | Pylon들에게 |

### 2. Pylon (estelle-pylon)

**역할**: PC 백그라운드 서비스

**핵심 원칙**: **Single Source of Truth**
- 모든 상태(워크스페이스, 메시지, Claude 세션)는 Pylon이 관리
- 클라이언트는 Pylon의 이벤트를 받아서 표시만 함
- 여러 클라이언트가 동일한 상태를 보장

**모듈 구성**:

| 모듈 | 역할 |
|------|------|
| `claudeManager.js` | Claude SDK 세션 관리 |
| `workspaceStore.js` | 워크스페이스 CRUD, 영속화 |
| `messageStore.js` | 메시지 히스토리 저장/로드 |
| `relayClient.js` | Relay WebSocket 연결 |
| `localServer.js` | 로컬 HTTP/WS 서버 (Desktop용) |
| `commandWatcher.js` | 파일 기반 명령어 감시 |
| `packetLogger.js` | 패킷 로깅 |
| `fileSimulator.js` | inbox 파일 시뮬레이션 |
| `taskManager.js` | Task 관리 |
| `workerManager.js` | Worker 관리 |
| `folderManager.js` | 폴더 탐색 |

**연결**:
- Relay에 WebSocket 연결 (인증 후 유지)
- 로컬 서버 (localhost:9000) - Desktop App 직접 연결용

### 3. App (estelle-app)

**역할**: 통합 클라이언트 앱 (Flutter)

**지원 플랫폼**:
- Windows (Desktop)
- Android (Mobile)
- Web

**연결 방식**:
- **Primary**: Relay에 WebSocket 연결
- **Secondary**: Desktop에서 로컬 Pylon 연결 (localhost:9000)

**상태관리**: Riverpod
- `RelayProvider`: Relay 연결 상태
- `WorkspaceProvider`: 워크스페이스 목록/선택
- `ClaudeProvider`: Claude 메시지/이벤트
- `SettingsProvider`: 앱 설정

---

## 통신 흐름

### 1. 인증 흐름

```
App                          Relay                         Pylon
 │                             │                             │
 │──── auth ──────────────────►│                             │
 │     {deviceType: 'app'}     │                             │
 │                             │                             │
 │◄─── auth_result ────────────│                             │
 │     {deviceId: 100}         │                             │
 │                             │                             │
 │                             │◄──── auth ──────────────────│
 │                             │      {deviceId: 1,          │
 │                             │       deviceType: 'pylon'}  │
 │                             │                             │
 │                             │──── auth_result ───────────►│
 │                             │     {success: true}         │
 │                             │                             │
 │◄─── device_status ──────────│──── device_status ─────────►│
 │     (연결된 디바이스 목록)   │                             │
```

### 2. 메시지 송수신 흐름

```
App                          Relay                         Pylon
 │                             │                             │
 │──── claude_send ───────────►│                             │
 │     {conversationId,        │                             │
 │      message}               │──── claude_send ───────────►│
 │                             │                             │
 │                             │                             │── Claude SDK
 │                             │                             │   실행
 │                             │                             │
 │◄─── claude_event ───────────│◄─── claude_event ──────────│
 │     {type: 'textDelta'}     │     (스트리밍 텍스트)       │
 │                             │                             │
 │◄─── claude_event ───────────│◄─── claude_event ──────────│
 │     {type: 'toolInfo'}      │     (도구 사용 시작)        │
 │                             │                             │
 │◄─── claude_event ───────────│◄─── claude_event ──────────│
 │     {type: 'toolComplete'}  │     (도구 사용 완료)        │
 │                             │                             │
 │◄─── claude_event ───────────│◄─── claude_event ──────────│
 │     {type: 'result'}        │     (최종 결과)             │
```

### 3. 권한 요청 흐름

```
App                          Relay                         Pylon
 │                             │                             │
 │◄─── claude_event ───────────│◄─── claude_event ──────────│
 │     {type: 'permission',    │     (권한 요청)             │
 │      tool, input}           │                             │
 │                             │                             │
 │     [사용자 응답]           │                             │
 │                             │                             │
 │──── claude_permission ─────►│──── claude_permission ─────►│
 │     {toolUseId, decision}   │                             │
 │                             │                             │── Claude SDK
 │                             │                             │   계속 실행
```

### 4. 세션 뷰어 시스템

Pylon은 각 클라이언트가 어떤 세션을 보고 있는지 추적:

```javascript
// Pylon 내부
sessionViewers: Map<sessionId, Set<clientDeviceId>>

// 클라이언트가 대화 선택 시
registerSessionViewer(clientId, sessionId)
  → 이전 세션에서 제거
  → 새 세션에 등록

// Claude 이벤트 전송 시
sendClaudeEvent(sessionId, event)
  → 해당 세션의 viewer들에게만 전송
  → to: Array.from(viewers)
```

**목적**:
- 불필요한 이벤트 전송 방지
- 여러 클라이언트가 다른 세션을 볼 때 각자에게만 전송

---

## 로컬 연결 (Desktop)

Desktop App은 두 가지 연결 사용:

1. **Relay 연결**: 다른 Pylon들의 워크스페이스 접근
2. **로컬 연결**: 같은 PC의 Pylon에 직접 연결 (localhost:9000)

```
Desktop App
    │
    ├── Relay (wss://estelle-relay.fly.dev)
    │   └── 다른 PC의 Pylon들
    │
    └── Local (ws://localhost:9000)
        └── 같은 PC의 Pylon
            └── 더 빠른 응답
```

---

## 데이터 저장

### Pylon 저장 위치

```
estelle-pylon/
├── workspaces.json         # 워크스페이스 목록
├── messages/               # 대화별 메시지 히스토리
│   └── {conversationId}.json
├── logs/                   # 패킷 로그
│   └── packets-{timestamp}.jsonl
├── persona/                # 스킬별 페르소나
│   ├── general.md
│   ├── planner.md
│   └── worker.md
└── pylon-settings.json     # Pylon 설정
```

### App 저장 (로컬)

- SharedPreferences / SecureStorage
- 설정값만 저장, 메시지는 Pylon에서 가져옴

---

## 관련 문서

- [message-protocol.md](./message-protocol.md) - 메시지 상세 스펙
- [device-id.md](./device-id.md) - Device ID 체계
- [pylon/overview.md](../pylon/overview.md) - Pylon 상세
- [relay/overview.md](../relay/overview.md) - Relay 상세
