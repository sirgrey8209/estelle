# ClaudeManager

> Claude Agent SDK 기반 세션 관리 모듈

## 위치

`estelle-pylon/src/claudeManager.js`

---

## 역할

- Claude SDK `query()` 실행 및 이벤트 처리
- 권한 요청 / 질문 요청 처리
- 세션 상태 관리 (working/idle/permission)
- 자동 허용/거부 규칙 적용

---

## 생성자

```javascript
new ClaudeManager(onEvent)
```

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `onEvent` | `Function(sessionId, event)` | 이벤트 콜백 |

---

## 내부 상태

| 상태 | 타입 | 설명 |
|------|------|------|
| `sessions` | `Map<sessionId, Session>` | 활성 세션 |
| `pendingPermissions` | `Map<toolUseId, Pending>` | 대기 중인 권한 요청 |
| `pendingQuestions` | `Map<toolUseId, Pending>` | 대기 중인 질문 |
| `pendingEvents` | `Map<sessionId, Event>` | 재연결 시 전송할 이벤트 |

### Session 구조

```javascript
{
  query,              // query 인스턴스
  abortController,    // AbortController
  claudeSessionId,    // Claude 세션 ID
  state: { type },    // 상태 (thinking/responding/tool)
  partialText,        // 스트리밍 텍스트 버퍼
  startTime,          // 시작 시간
  pendingTools,       // Map<toolUseId, toolName>
  usage: {            // 토큰 사용량
    inputTokens,
    outputTokens,
    cacheReadInputTokens,
    cacheCreationInputTokens
  }
}
```

---

## 주요 메서드

### sendMessage(sessionId, message, options)

Claude에게 메시지 전송

```javascript
await claudeManager.sendMessage(conversationId, message, {
  workingDir: '/path/to/workspace',
  claudeSessionId: 'resume-session-id'  // 선택
});
```

**처리 흐름**:
1. 이미 실행 중이면 중지
2. `state: working` 이벤트 emit
3. `runQuery()` 실행
4. 완료/에러 시 세션 삭제
5. `state: idle` 이벤트 emit

### stop(sessionId)

세션 강제 중지

```javascript
claudeManager.stop(conversationId);
```

**처리**:
1. AbortController.abort() 시도
2. 세션 강제 삭제
3. `state: idle` emit
4. 대기 중인 권한/질문 모두 거부

### newSession(sessionId)

새 세션 시작 (기존 세션 종료)

### respondPermission(sessionId, toolUseId, decision)

권한 응답

| decision | 결과 |
|----------|------|
| `allow` | `{ behavior: 'allow' }` |
| `allowAll` | `{ behavior: 'allow' }` |
| `deny` | `{ behavior: 'deny', message: 'User denied' }` |

### respondQuestion(sessionId, toolUseId, answer)

질문 응답

```javascript
claudeManager.respondQuestion(sessionId, toolUseId, 'Option A');
```

---

## 이벤트 타입

ClaudeManager가 emit하는 이벤트:

### init
세션 초기화
```javascript
{ type: 'init', session_id, model, tools }
```

### stateUpdate
상태 변경 (UI 상태 표시용)
```javascript
{ type: 'stateUpdate', state: { type: 'thinking'|'responding'|'tool' }, partialText }
```

### text
스트리밍 텍스트 델타
```javascript
{ type: 'text', content: '텍스트 일부' }
```

### textComplete
텍스트 완료
```javascript
{ type: 'textComplete', text: '전체 텍스트' }
```

### toolInfo
도구 실행 시작
```javascript
{ type: 'toolInfo', toolName: 'Read', input: { file_path: '...' } }
```

### toolComplete
도구 실행 완료
```javascript
{ type: 'toolComplete', toolName: 'Read', success: true, result: '...', error: undefined }
```

### askQuestion
사용자 질문 (AskUserQuestion 도구)
```javascript
{ type: 'askQuestion', questions: [...], toolUseId: '...' }
```

### permission_request
권한 요청
```javascript
{ type: 'permission_request', toolName: 'Write', toolInput: {...}, toolUseId: '...' }
```

### state
상태 변경 (idle/working/permission)
```javascript
{ type: 'state', state: 'working' }
```

### result
처리 완료
```javascript
{
  type: 'result',
  subtype: 'end_turn',
  duration_ms: 5000,
  total_cost_usd: 0.015,
  num_turns: 3,
  usage: {
    inputTokens: 10000,
    outputTokens: 2000,
    cacheReadInputTokens: 8000,
    cacheCreationInputTokens: 0
  }
}
```

### error
에러
```javascript
{ type: 'error', error: '에러 메시지' }
```

---

## 권한 처리 규칙

### 권한 모드

| 모드 | 동작 |
|------|------|
| `default` | 자동 허용/거부 규칙 적용 |
| `acceptEdits` | Edit, Write, Bash, NotebookEdit 자동 허용 |
| `bypassPermissions` | 모든 도구 자동 허용 (AskUserQuestion 제외) |

### 자동 허용 도구

```javascript
autoAllowTools = ['Read', 'Glob', 'Grep', 'WebSearch', 'WebFetch', 'TodoWrite']
```

### 자동 거부 패턴

| 도구 | 패턴 | 이유 |
|------|------|------|
| Edit | `\.(env\|secret\|credentials\|password)` | Protected file |
| Write | `\.(env\|secret\|credentials\|password)` | Protected file |
| Bash | `rm -rf /`, `format`, `shutdown` 등 | Dangerous command |

### 권한 결정 흐름

```
1. bypassPermissions 모드? → 자동 허용 (AskUserQuestion 제외)
2. acceptEdits 모드? → Edit/Write/Bash 자동 허용
3. autoAllowTools? → 자동 허용
4. autoDenyPatterns 매칭? → 자동 거부
5. 위 모두 아님 → 사용자에게 요청
```

---

## MCP 서버 지원

워크스페이스의 `.mcp.json` 파일에서 MCP 서버 설정 로드:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "node",
      "args": ["server.js"],
      "cwd": "./mcp"
    }
  }
}
```

---

## 로깅

```
logs/sdk-{date}.jsonl
```

| 필드 | 설명 |
|------|------|
| `timestamp` | 타임스탬프 |
| `sessionId` | 대화 ID |
| `direction` | `input` / `output` |
| `data` | 이벤트 데이터 |

---

## 관련 문서

- [overview.md](./overview.md) - Pylon 개요
- [workspace-store.md](./workspace-store.md) - 워크스페이스 저장소
- [../system/message-protocol.md](../system/message-protocol.md) - 메시지 프로토콜
