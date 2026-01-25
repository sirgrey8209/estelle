# Pylon 개요

> PC 백그라운드 서비스 - Claude SDK 실행 및 워크스페이스 관리

## 기본 정보

| 항목 | 값 |
|------|-----|
| 런타임 | Node.js (ESM) |
| 포트 | 9000 (로컬 서버) |
| 프로세스 관리 | PM2 |
| Relay 연결 | WebSocket |

---

## 모듈 구조

```
estelle-pylon/
├── src/
│   ├── index.js              # 메인 진입점 (Pylon 클래스)
│   ├── claudeManager.js      # Claude SDK 세션 관리
│   ├── workspaceStore.js     # 워크스페이스 CRUD
│   ├── messageStore.js       # 메시지 히스토리
│   ├── relayClient.js        # Relay 연결 (현재 index.js에 통합)
│   ├── localServer.js        # 로컬 HTTP/WS 서버
│   ├── commandWatcher.js     # 파일 기반 명령어
│   ├── packetLogger.js       # 패킷 로깅
│   ├── fileSimulator.js      # inbox 파일 시뮬레이션
│   ├── taskManager.js        # Task 관리
│   ├── workerManager.js      # Worker 관리
│   ├── folderManager.js      # 폴더 탐색
│   ├── pidManager.js         # PID 파일 관리
│   └── logger.js             # 로깅
│
├── persona/                  # 스킬별 페르소나
│   ├── general.md
│   ├── planner.md
│   └── worker.md
│
├── messages/                 # 대화별 메시지 히스토리
│   └── {conversationId}.json
│
├── logs/                     # 로그 파일
│   ├── packets-{date}.jsonl
│   └── sdk-{date}.jsonl
│
├── workspaces.json          # 워크스페이스 목록
└── pylon-settings.json      # Pylon 설정
```

---

## 핵심 원칙: Single Source of Truth

Pylon이 모든 상태의 유일한 출처:

| 상태 | 저장 위치 | 설명 |
|------|-----------|------|
| 워크스페이스 | `workspaces.json` | 워크스페이스, 대화 목록 |
| 메시지 히스토리 | `messages/*.json` | 대화별 메시지 |
| Claude 세션 | 메모리 (ClaudeManager) | 실행 중인 세션 |
| 권한/질문 요청 | 메모리 (ClaudeManager) | 대기 중인 요청 |

클라이언트(App)는 Pylon으로부터 받은 데이터를 표시만 하고, 상태를 직접 관리하지 않음.

---

## 시작 흐름

```
1. PidManager.initialize()
   └── pylon.pid 파일 생성

2. checkAndUpdate()
   └── GitHub Release에서 deploy.json 확인
   └── 버전 불일치 시 p2-update.ps1 실행

3. workspaceStore.initialize()
   └── workspaces.json 로드

4. ClaudeManager 생성
   └── 이벤트 콜백 설정

5. LocalServer 시작
   └── localhost:9000 리스닝

6. FileSimulator 초기화 (선택)
   └── debug/inbox 폴더 감시

7. connectToRelay()
   └── WebSocket 연결
   └── 인증
```

---

## 연결 관리

### Relay 연결

```javascript
// 연결
connectToRelay()
  → WebSocket.connect(RELAY_URL)
  → 연결 성공 → authenticate()
  → auth_result 수신 → broadcastWorkspaceList()

// 재연결
scheduleReconnect()
  → 5초 후 connectToRelay()
```

### 로컬 서버 (Desktop App용)

```javascript
localServer.onConnect(ws)
  → 워크스페이스 목록 전송
  → Relay 연결 상태 전송

localServer.onMessage(data, ws)
  → ping/pong
  → get_status
  → run_deploy
  → 기타 메시지 → handleMessage()
```

---

## 메시지 처리

`handleMessage(message)`:

### 워크스페이스 관련

| 타입 | 처리 |
|------|------|
| `workspace_list` | 워크스페이스 목록 반환 |
| `workspace_create` | 새 워크스페이스 생성 |
| `workspace_delete` | 워크스페이스 삭제 |
| `workspace_rename` | 워크스페이스 이름 변경 |
| `workspace_switch` | 활성 워크스페이스 변경 |
| `conversation_create` | 새 대화 생성 + 페르소나 주입 |
| `conversation_select` | 대화 선택 + 히스토리 전송 |
| `conversation_delete` | 대화 삭제 |
| `conversation_rename` | 대화 이름 변경 |

### Claude 관련

| 타입 | 처리 |
|------|------|
| `claude_send` | 메시지 전송 → ClaudeManager |
| `claude_permission` | 권한 응답 |
| `claude_answer` | 질문 응답 |
| `claude_control` | stop, new_session, clear |
| `claude_set_permission_mode` | 권한 모드 변경 |

### 기타

| 타입 | 처리 |
|------|------|
| `history_request` | 메시지 히스토리 페이징 |
| `folder_list` | 폴더 목록 |
| `task_list` | 태스크 목록 |
| `worker_start` | 워커 시작 |
| `deploy_*` | 배포 관련 |
| `version_check_request` | 버전 확인 |
| `bug_report` | 버그 리포트 저장 |

---

## 세션 뷰어 시스템

클라이언트가 어떤 세션을 보고 있는지 추적:

```javascript
sessionViewers: Map<sessionId, Set<clientDeviceId>>

// 클라이언트가 대화 선택 시
registerSessionViewer(clientId, sessionId)
  → 이전 세션에서 제거
  → 새 세션에 등록

// Claude 이벤트 전송 시
sendClaudeEvent(sessionId, event)
  → 해당 세션의 viewer들에게만 전송
  → to: Array.from(viewers)

// 클라이언트 연결 해제 시
unregisterSessionViewer(clientId)
  → 모든 시청 정보 제거
  → 빈 세션 캐시 해제
```

---

## 페르소나 시스템

대화 생성 시 스킬 타입에 따라 페르소나 주입:

```javascript
loadPersona(skillType)
  → persona/{skillType}.md 파일 로드
  → 없으면 null

// 대화 생성 시
const personaContent = this.loadPersona(skillType);
const greeting = this.getInitialGreeting(skillType);
let prompt = `<persona>\n${personaContent}\n</persona>\n\n${greeting}`;
claudeManager.sendMessage(conversationId, prompt, { workingDir });
```

### 스킬 타입

| 타입 | 인사 | 용도 |
|------|------|------|
| `general` | "안녕!" | 일반 대화 |
| `planner` | "작업 계획을 논의하고 싶어." | 계획 수립 |
| `worker` | "작업을 시작하자." | 구현 |

---

## 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `RELAY_URL` | `ws://localhost:8080` | Relay 서버 URL |
| `LOCAL_PORT` | `9000` | 로컬 서버 포트 |
| `DEVICE_ID` | `1` | Pylon Device ID |
| `FILE_SIMULATOR` | `false` | 파일 시뮬레이터 활성화 |

---

## 관련 문서

- [claude-manager.md](./claude-manager.md) - Claude SDK 관리
- [workspace-store.md](./workspace-store.md) - 워크스페이스 저장소
- [message-store.md](./message-store.md) - 메시지 저장소
- [../system/architecture.md](../system/architecture.md) - 시스템 아키텍처
