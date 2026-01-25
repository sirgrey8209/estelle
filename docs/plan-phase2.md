# Estelle Phase 2 - Claude Code 원격 제어 시스템

## 목표

**어느 디바이스에서든 두 PC의 Claude Code를 완전히 제어할 수 있는 기반 구축**

Slack 파트를 직접 구현하여, WebSocket을 통한 실시간 양방향 통신으로 Claude Code를 원격 제어한다.

## 핵심 설계 원칙

### 1. JSON 스트림 직접 전달
```
Claude SDK → Pylon → Relay → Client (Mobile/Desktop)
         (JSON 이벤트 그대로 스트리밍)
```

- Slack처럼 메시지 가공 없음
- SDK 이벤트를 그대로 클라이언트로 전달
- 클라이언트가 "Claude Code 렌더러" 역할

### 2. 로그 기반 TDD 개발
```
[실제 SDK 출력 로깅] → [테스트 케이스 자동 생성] → [렌더러 TDD 개발]
```

- Pylon에서 모든 SDK 입출력 로깅
- 로그를 테스트 케이스로 변환
- 렌더러를 테스트 기반으로 단단하게 구현
- 엣지 케이스 자동 발견, 회귀 테스트 자동화

### 3. 인증
- IP/MAC 화이트리스트 기반
- 등록된 기기만 접속 가능

### 4. PC/워크스페이스 선택
- 통합 목록: 모든 PC의 모든 워크스페이스를 한 목록에서 선택
- 형식: `{PC이름}/{워크스페이스이름}` (예: `집PC/estelle`, `회사PC/eb`)

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        Relay (Fly.io)                           │
│  - WebSocket 허브                                                │
│  - IP/MAC 인증                                                   │
│  - 메시지 라우팅 (Client ↔ Pylon)                                │
│  - 기기/워크스페이스 목록 관리                                      │
└─────────────────────────────────────────────────────────────────┘
          ▲                                      ▲
          │ WSS                                  │ WSS
          ▼                                      ▼
┌─────────────────────┐                ┌─────────────────────┐
│   Pylon (집 PC)     │                │   Pylon (회사 PC)   │
│  - Claude SDK 실행   │                │  - Claude SDK 실행   │
│  - 워크스페이스 관리  │                │  - 워크스페이스 관리  │
│  - SDK 입출력 로깅   │                │  - SDK 입출력 로깅   │
└─────────────────────┘                └─────────────────────┘
          ▲                                      ▲
          │ localhost                            │ localhost
          ▼                                      ▼
┌─────────────────────┐                ┌─────────────────────┐
│  Desktop (집 PC)    │                │  Desktop (회사 PC)  │
│  - 로컬 UI (옵션)    │                │  - 로컬 UI (옵션)    │
└─────────────────────┘                └─────────────────────┘

                           ▲
                           │ WSS
                           ▼
                  ┌─────────────────┐
                  │  Mobile (어디서든) │
                  │  - Claude 렌더러  │
                  │  - 전체 제어 UI   │
                  └─────────────────┘
```

---

## 메시지 프로토콜

### 1. 기본 구조

```typescript
interface Message {
  type: string;
  from: DeviceId;      // 발신자
  to?: DeviceId;       // 수신자 (없으면 broadcast)
  payload: any;
  timestamp: number;
  requestId?: string;  // 요청-응답 매칭용
}

interface DeviceId {
  pcId: string;        // PC 식별자 (예: "home", "office")
  deviceType: 'pylon' | 'desktop' | 'mobile';
}
```

### 2. 인증 (Client → Relay)

```typescript
// 연결 시 인증 요청
{
  type: 'auth',
  payload: {
    pcId: string;
    deviceType: 'pylon' | 'desktop' | 'mobile';
    mac?: string;  // Pylon만 필수
  }
}

// 인증 응답
{
  type: 'auth_result',
  payload: {
    success: boolean;
    error?: string;
    deviceId: DeviceId;
  }
}
```

### 3. 워크스페이스 관리

```typescript
// 워크스페이스 목록 요청
{ type: 'workspace_list' }

// 워크스페이스 목록 응답 (모든 PC의 모든 워크스페이스)
{
  type: 'workspace_list_result',
  payload: {
    workspaces: Array<{
      pcId: string;
      pcName: string;
      workspaceId: string;
      workspaceName: string;
      workingDir: string;
      status: 'idle' | 'working' | 'permission' | 'offline';
      isActive: boolean;  // 해당 PC에서 활성화된 워크스페이스인지
    }>
  }
}

// 워크스페이스 전환
{
  type: 'workspace_switch',
  payload: { pcId: string; workspaceId: string; }
}

// 워크스페이스 생성
{
  type: 'workspace_create',
  payload: { pcId: string; name: string; workingDir: string; }
}

// 워크스페이스 삭제
{
  type: 'workspace_delete',
  payload: { pcId: string; workspaceId: string; }
}

// 워크스페이스 이름 변경
{
  type: 'workspace_rename',
  payload: { pcId: string; workspaceId: string; newName: string; }
```

### 4. Claude 제어 (SlackClaudeBot 기능 이식)

```typescript
// 메시지 전송 (프롬프트)
{
  type: 'claude_send',
  to: { pcId, deviceType: 'pylon' },
  payload: {
    workspaceId: string;
    conversationId: string;
    message: string;
  }
}

// Claude SDK 이벤트 스트리밍 (Pylon → Client)
// SDK에서 나오는 이벤트를 그대로 전달
{
  type: 'claude_event',
  payload: {
    conversationId: string;
    event: ClaudeSdkEvent;  // 원본 SDK 이벤트
  }
}

// SDK 이벤트 타입들 (Claude SDK 원본)
type ClaudeSdkEvent =
  | { type: 'state', state: AgentState }
  | { type: 'text', content: string }
  | { type: 'tool_start', toolName: string, toolInput: any }
  | { type: 'tool_complete', toolName: string, output: any }
  | { type: 'permission_request', toolName: string, toolInput: any, toolUseId: string }
  | { type: 'ask_question', question: string, options: string[], toolUseId: string }
  | { type: 'result', result: any }
  | { type: 'error', error: string };

// 권한 응답
{
  type: 'claude_permission',
  to: { pcId, deviceType: 'pylon' },
  payload: {
    conversationId: string;
    toolUseId: string;
    decision: 'allow' | 'deny' | 'allowAll';
  }
}

// 질문 응답
{
  type: 'claude_answer',
  to: { pcId, deviceType: 'pylon' },
  payload: {
    conversationId: string;
    toolUseId: string;
    answer: string;
  }
}

// 세션 제어
{
  type: 'claude_control',
  to: { pcId, deviceType: 'pylon' },
  payload: {
    conversationId: string;
    action: 'stop' | 'new_session' | 'clear' | 'compact';
  }
}

// 권한 모드 변경
{
  type: 'claude_set_permission_mode',
  to: { pcId, deviceType: 'pylon' },
  payload: {
    mode: 'default' | 'acceptEdits' | 'bypassPermissions';
  }
}
```

---

## 컴포넌트별 구현 상세

### 1. estelle-relay

**역할:** WebSocket 허브, 인증, 메시지 라우팅

```
src/
├── index.ts              # 엔트리포인트
├── auth.ts               # IP/MAC 인증
├── device-registry.ts    # 연결된 기기 관리
├── router.ts             # 메시지 라우팅
└── types.ts              # 공유 타입 정의
```

**구현 사항:**
- [x] WebSocket 서버 (Phase 1 완료)
- [ ] IP/MAC 화이트리스트 인증
- [ ] 기기 레지스트리 (연결된 Pylon/Client 목록)
- [ ] 메시지 라우팅 (특정 기기로 전달)
- [ ] 워크스페이스 목록 집계 (모든 Pylon에서 수집)
- [ ] 오프라인 기기 감지 및 상태 업데이트

### 2. estelle-pylon

**역할:** Claude SDK 실행, 워크스페이스 관리, SDK 입출력 로깅

```
src/
├── index.ts              # 엔트리포인트
├── relay-client.ts       # Relay 연결 관리
├── claude-manager.ts     # Claude SDK 인스턴스 관리
├── workspace-store.ts    # 워크스페이스 영속 저장
├── sdk-logger.ts         # SDK 입출력 로깅 (테스트 케이스용)
└── types.ts              # 타입 정의
```

**구현 사항:**
- [x] Relay 연결 (Phase 1 완료)
- [ ] Claude SDK 통합 (@anthropic-ai/claude-code)
- [ ] 워크스페이스 관리 (생성/삭제/전환/이름변경)
- [ ] SDK 이벤트 → WebSocket 스트리밍
- [ ] 권한/질문 요청 처리
- [ ] 세션 제어 (stop, new, clear, compact)
- [ ] **SDK 입출력 로깅** (JSON 파일로 저장)
  - 입력: 사용자 메시지, 권한 응답, 질문 응답
  - 출력: 모든 SDK 이벤트
  - 테스트 케이스 자동 생성용

**SDK 로깅 형식:**
```typescript
interface SdkLog {
  timestamp: number;
  sessionId: string;
  conversationId: string;
  direction: 'input' | 'output';
  data: any;
}

// 로그 파일: logs/sdk-{date}.jsonl
// 각 줄이 하나의 SdkLog JSON
```

### 3. estelle-mobile

**역할:** Claude Code 렌더러, 전체 제어 UI

```
app/src/main/java/com/example/estelle/
├── MainActivity.kt
├── data/
│   ├── WebSocketClient.kt      # Relay 연결
│   ├── MessageRepository.kt    # 메시지 상태 관리
│   └── WorkspaceRepository.kt  # 워크스페이스 상태 관리
├── ui/
│   ├── chat/
│   │   ├── ChatScreen.kt       # 메인 채팅 UI
│   │   └── MessageRenderer.kt  # Claude 이벤트 렌더링
│   ├── workspace/
│   │   ├── WorkspaceListScreen.kt   # 워크스페이스 선택 (통합 목록)
│   │   └── WorkspaceItem.kt         # 워크스페이스 아이템 컴포넌트
│   └── components/
│       ├── ToolCallView.kt     # 툴 호출 표시
│       ├── PermissionDialog.kt # 권한 요청 다이얼로그
│       └── CodeBlock.kt        # 코드 블록 렌더링
└── util/
    └── ClaudeEventParser.kt    # SDK 이벤트 파싱
```

**구현 사항:**
- [x] Relay 연결 (Phase 1 완료)
- [ ] Claude 이벤트 렌더러 (핵심!)
  - text → 마크다운 렌더링
  - tool_start/tool_complete → 툴 호출 UI
  - permission_request → 권한 다이얼로그
  - ask_question → 선택지 UI
  - state → 상태 표시
- [ ] 워크스페이스 선택 UI (통합 목록)
- [ ] 메시지 입력 및 전송
- [ ] 세션 제어 버튼 (stop, new, clear, compact)
- [ ] 권한 모드 설정

### 4. estelle-desktop

**역할:** 로컬 UI (선택적), Pylon 상태 표시

Phase 2에서는 최소 구현:
- Pylon 연결 상태 표시
- 현재 워크스페이스 정보
- 간단한 메시지 전송 (급할 때 로컬에서)

---

## 개발 순서

### Step 1: 프로토콜 & 타입 정의
- [ ] `estelle-shared` 패키지 생성 (공유 타입)
- [ ] 메시지 프로토콜 타입 정의
- [ ] SDK 이벤트 타입 정의

### Step 2: Relay 인증 & 라우팅
- [ ] IP/MAC 화이트리스트 구현
- [ ] 기기 레지스트리 구현
- [ ] 메시지 라우팅 구현
- [ ] 워크스페이스 목록 집계 API

### Step 3: Pylon - Claude SDK 통합
- [ ] Claude SDK 설치 및 설정
- [ ] SDK 이벤트 스트리밍 구현
- [ ] **SDK 로거 구현** (테스트 케이스용)
- [ ] workspace-store 구현
- [ ] 세션 제어 구현

### Step 4: Mobile - 렌더러 개발 (TDD)
- [ ] SDK 로그에서 테스트 케이스 생성
- [ ] 이벤트 파서 구현 + 테스트
- [ ] 렌더러 컴포넌트 구현 + 테스트
- [ ] 워크스페이스 선택 UI
- [ ] 전체 통합

### Step 5: 통합 테스트
- [ ] Mobile → Relay → Pylon → Claude SDK 전체 흐름
- [ ] 두 PC 동시 연결 테스트
- [ ] 오프라인/재연결 테스트

---

## 테스트 전략

### 렌더러 TDD 워크플로우

```
1. Pylon에서 실제 Claude 사용하며 로그 수집
   └── logs/sdk-2025-01-21.jsonl

2. 로그를 테스트 케이스로 변환
   └── test/fixtures/text-streaming.json
   └── test/fixtures/tool-call-read.json
   └── test/fixtures/permission-bash.json

3. 테스트 먼저 작성
   └── ClaudeEventParserTest.kt
   └── MessageRendererTest.kt

4. 렌더러 구현
   └── 테스트 통과할 때까지 구현

5. 새 이벤트 타입 발견 시 → 1번으로
```

### 테스트 케이스 예시

```json
// test/fixtures/tool-call-read.json
{
  "name": "Read tool call with file content",
  "events": [
    { "type": "tool_start", "toolName": "Read", "toolInput": { "file_path": "/app/src/main.kt" } },
    { "type": "tool_complete", "toolName": "Read", "output": "package com.example..." }
  ],
  "expected": {
    "ui": "collapsed tool card with file icon",
    "expandable": true,
    "showsFilePath": true
  }
}
```

---

## 참고: SlackClaudeBot에서 이식할 것

### 이식 O (핵심 로직)
- `workspace-store.ts` → Pylon의 워크스페이스 관리
- `claude-sdk.ts` 사용 패턴 → Pylon의 SDK 통합
- 권한 모드 관리 로직
- 세션 제어 로직 (stop, new, clear, compact)

### 이식 X (Slack 전용)
- Slack API 호출 (chat.postMessage 등)
- 메시지 분할 (splitMessage) - WebSocket은 제한 없음
- Slack mrkdwn 이스케이프 - 클라이언트에서 직접 렌더링
- SlackApiQueue - Slack rate limit용

---

## 완료 기준

Phase 2 완료 조건:
1. ✅ 모바일에서 두 PC의 워크스페이스 목록 확인 가능
2. ✅ 모바일에서 워크스페이스 선택 후 Claude에게 메시지 전송 가능
3. ✅ Claude 응답이 실시간으로 모바일에 스트리밍
4. ✅ 권한 요청 시 모바일에서 승인/거부 가능
5. ✅ 세션 제어 (stop, new, clear) 동작
6. ✅ IP/MAC 인증으로 허가된 기기만 접속

---

## Phase 3 예정 (나중에)

- **캐릭터 페르소나**: Selene/Stella가 대화하는 느낌으로 Claude 응답 렌더링
- 캐릭터별 말투, 아이콘, 테마 색상 등

---

## 일정 (예상)

| 단계 | 기간 | 산출물 |
|------|------|--------|
| Step 1: 타입 정의 | 1일 | estelle-shared 패키지 |
| Step 2: Relay 인증 | 2일 | 인증 & 라우팅 동작 |
| Step 3: Pylon SDK | 3일 | SDK 통합 & 로깅 |
| Step 4: Mobile 렌더러 | 4일 | TDD 기반 렌더러 |
| Step 5: 통합 테스트 | 2일 | E2E 동작 확인 |
| **총합** | **~12일** | Phase 2 완료 |
