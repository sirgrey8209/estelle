# Claude SDK 프로세스 분리 설계

> Pylon 재시작 시에도 Claude 세션이 유지되도록 SDK를 별도 프로세스로 분리

## 1. 배경 및 문제

### 현재 구조

```
estelle-pylon (PM2)
    └── ClaudeManager (in-process)
        └── SDK query() 호출
            └── SDK가 spawn한 프로세스들 (claude-agent-sdk, MCP 서버)
```

### 문제점

1. **Pylon 재시작 시 Claude 세션 손실**
   - ClaudeManager가 Pylon 프로세스 내부에서 동작
   - Pylon 재시작 → 메모리의 세션 정보(this.sessions) 소멸
   - 진행 중이던 작업이 중단됨

2. **개발 생산성 저하**
   - Worker가 긴 작업 수행 중일 때 Pylon 수정 불가
   - Pylon 개발을 위해 작업 완료까지 대기해야 함

3. **재연결 시 상태 불일치**
   - SDK 프로세스는 살아있을 수 있으나 연결 불가
   - 사용자가 수동으로 세션 재시작 필요

---

## 2. 목표

1. **Pylon과 Claude SDK 생명주기 분리**
   - Pylon 재시작해도 Claude 세션 유지
   - 재연결 시 기존 상태 그대로 복구

2. **기존 기능 100% 호환**
   - ClaudeManager가 제공하는 모든 기능 유지
   - canUseTool 콜백 포함 완벽 지원

3. **최소한의 구조 변경**
   - 기존 코드 최대한 재사용
   - Pylon 쪽 수정 최소화

---

## 3. 해결 방향: PM2 IPC 기반 프로세스 분리

### 변경 후 구조

```
┌─────────────────────────────────────────────────────────────┐
│                        PM2                                   │
│  ┌─────────────────┐         ┌─────────────────────────┐   │
│  │ estelle-pylon   │◄──IPC──►│ estelle-claude-sdk      │   │
│  │                 │         │                         │   │
│  │ - Relay 통신    │         │ - SDK query() 실행     │   │
│  │ - 워크스페이스  │         │ - 세션 상태 관리       │   │
│  │ - UI 이벤트     │         │ - 권한 대기/응답       │   │
│  │                 │         │ - MCP 서버 관리        │   │
│  └─────────────────┘         └─────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### PM2 IPC를 선택한 이유

| 방식 | 장점 | 단점 |
|------|------|------|
| HTTP | 디버깅 쉬움 | 폴링 필요, canUseTool 대기 어색 |
| WebSocket | 양방향 | 추가 포트, 연결 관리 필요 |
| **PM2 IPC** | 이미 사용 중, 추가 포트 불필요, 양방향 | PM2 의존 |
| Redis | 확장성 | 과도한 의존성 |

→ 이미 PM2를 사용 중이고, 추가 인프라 없이 양방향 통신 가능

---

## 4. 역할 분리

### estelle-pylon (기존)

- Relay WebSocket 연결 및 메시지 라우팅
- 워크스페이스 관리 (workspaceStore)
- Worker 관리 (workerManager)
- 클라이언트 이벤트 처리
- Claude SDK Wrapper와 IPC 통신

**제거되는 것:**
- ClaudeManager 클래스 (estelle-claude-sdk로 이동)
- SDK 직접 호출

### estelle-claude-sdk (신규)

- Claude Agent SDK 래핑
- 세션 생명주기 관리
- canUseTool 권한 요청/대기
- MCP 서버 관리 (SDK가 자동 처리)
- 이벤트 스트리밍

**핵심 원칙:**
- Pylon 재시작해도 이 프로세스는 유지
- 세션 상태는 메모리 + 파일로 영속화

---

## 5. IPC 메시지 프로토콜

### Pylon → SDK Wrapper

```javascript
// 메시지 전송
{
  type: 'send_message',
  sessionId: 'conv_xxx',
  payload: {
    prompt: '...',
    workingDir: 'C:/workspace/project',
    workspaceId: 'ws_xxx',
    claudeSessionId: 'resume_xxx',  // optional, resume용
    mcpConfig: { ... }  // optional
  }
}

// 세션 중지
{
  type: 'stop_session',
  sessionId: 'conv_xxx'
}

// 새 세션 시작
{
  type: 'new_session',
  sessionId: 'conv_xxx'
}

// 권한 응답
{
  type: 'permission_response',
  sessionId: 'conv_xxx',
  toolUseId: 'perm_xxx',
  decision: 'allow' | 'deny' | 'allowAll'
}

// 질문 응답
{
  type: 'question_response',
  sessionId: 'conv_xxx',
  toolUseId: 'q_xxx',
  answer: '...'
}

// 상태 조회
{
  type: 'get_status',
  sessionId: 'conv_xxx'  // optional, 없으면 전체
}

// Pylon 재연결 알림
{
  type: 'pylon_reconnected'
}
```

### SDK Wrapper → Pylon

```javascript
// Claude 이벤트 (기존 ClaudeManager 이벤트와 동일)
{
  type: 'claude_event',
  sessionId: 'conv_xxx',
  event: {
    type: 'text' | 'textComplete' | 'toolInfo' | 'toolComplete' |
          'stateUpdate' | 'state' | 'init' | 'result' | 'error',
    ...eventData
  }
}

// 권한 요청 (canUseTool 콜백에서 발생)
{
  type: 'permission_request',
  sessionId: 'conv_xxx',
  toolUseId: 'perm_xxx',
  toolName: 'Edit',
  toolInput: { file_path: '...', ... }
}

// 질문 요청 (AskUserQuestion)
{
  type: 'question_request',
  sessionId: 'conv_xxx',
  toolUseId: 'q_xxx',
  questions: [...]
}

// 상태 응답
{
  type: 'status_response',
  sessions: [
    {
      sessionId: 'conv_xxx',
      state: 'idle' | 'working' | 'permission',
      claudeSessionId: '...',
      pendingPermission: { ... } | null,
      startTime: 12345
    }
  ]
}
```

---

## 6. canUseTool 처리 흐름

가장 까다로운 부분인 권한 처리 흐름:

```
1. SDK가 canUseTool 콜백 호출
   │
2. SDK Wrapper에서 Promise 생성, pendingResolvers에 저장
   │
3. IPC로 Pylon에 permission_request 전송
   │
4. Pylon이 클라이언트에 permission_request 이벤트 전달
   │
5. 사용자가 허용/거부 선택
   │
6. Pylon이 IPC로 permission_response 전송
   │
7. SDK Wrapper에서 pendingResolvers.get(toolUseId).resolve()
   │
8. SDK가 도구 실행 또는 거부 처리
```

### 코드 예시 (SDK Wrapper)

```javascript
// 대기 중인 권한 요청
const pendingResolvers = new Map();

// SDK query 옵션
const queryOptions = {
  canUseTool: async (toolName, input) => {
    const toolUseId = generateId();

    // Pylon에 권한 요청
    process.send({
      type: 'permission_request',
      sessionId,
      toolUseId,
      toolName,
      toolInput: input
    });

    // 응답 대기
    return new Promise(resolve => {
      pendingResolvers.set(toolUseId, { resolve, toolName, input });
    });
  }
};

// Pylon으로부터 응답 수신
process.on('message', (msg) => {
  if (msg.type === 'permission_response') {
    const pending = pendingResolvers.get(msg.toolUseId);
    if (pending) {
      pendingResolvers.delete(msg.toolUseId);

      if (msg.decision === 'allow' || msg.decision === 'allowAll') {
        pending.resolve({ behavior: 'allow', updatedInput: pending.input });
      } else {
        pending.resolve({ behavior: 'deny', message: 'User denied' });
      }
    }
  }
});
```

---

## 7. Pylon 재시작 시나리오

### 시나리오: Worker 작업 중 Pylon 재시작

```
Before Restart:
- Worker가 task_123 실행 중
- SDK Wrapper의 session conv_abc 활성

Pylon Restart:
1. Pylon 프로세스 종료
2. SDK Wrapper는 계속 실행 중 (PM2가 별도 관리)
3. SDK query()도 계속 진행

Pylon Reconnect:
1. Pylon 시작, PM2 IPC 연결
2. { type: 'pylon_reconnected' } 전송
3. SDK Wrapper가 현재 상태 전송:
   - 활성 세션 목록
   - 대기 중인 권한 요청
   - 진행 중인 작업 상태
4. Pylon이 상태 복구:
   - workerManager 상태 동기화
   - 클라이언트에 상태 브로드캐스트
5. 대기 중인 권한 요청이 있으면 클라이언트에 재전송
```

### 시나리오: 권한 대기 중 Pylon 재시작

```
Before Restart:
- SDK가 Edit 도구 사용 권한 요청 중
- 사용자 응답 대기 상태

Pylon Restart:
1. SDK Wrapper에서 pendingResolvers에 해당 요청 보관 중
2. Pylon 재시작

Pylon Reconnect:
1. SDK Wrapper가 pending 권한 요청 목록 전송
2. Pylon이 클라이언트에 permission_request 재전송
3. 사용자 응답 → 정상 처리
```

---

## 8. 예상 효과

### Before

| 상황 | 결과 |
|------|------|
| Worker 작업 중 Pylon 재시작 | 작업 중단, 사용자가 수동 재시작 필요 |
| Pylon 개발 중 Worker 실행 | 작업 완료까지 대기 |
| 권한 대기 중 Pylon 크래시 | 권한 요청 손실, 재시작 필요 |

### After

| 상황 | 결과 |
|------|------|
| Worker 작업 중 Pylon 재시작 | 작업 계속 진행, 재연결 시 상태 복구 |
| Pylon 개발 중 Worker 실행 | Pylon만 재시작, Worker 영향 없음 |
| 권한 대기 중 Pylon 크래시 | 재연결 시 권한 요청 재전송 |

---

## 9. 다음 단계

- [ ] 2단계: 상세 설계 (파일 구조, 코드 스켈레톤, 에러 처리)
- [ ] 3단계: 구현 가이드 (마이그레이션 계획, 테스트 방법)

---

*Created: 2026-01-29*
