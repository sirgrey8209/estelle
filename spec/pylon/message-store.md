# Message Store

> 세션별 메시지 히스토리 저장 모듈

## 위치

`estelle-pylon/src/messageStore.js`

---

## 역할

- 세션별 메시지 히스토리 관리
- 메모리 캐시 + Debounced 파일 저장
- 메시지 요약 (toolInput/output truncate)

---

## 상수

| 상수 | 값 | 설명 |
|------|-----|------|
| `MESSAGES_DIR` | `./messages` | 메시지 저장 폴더 |
| `MAX_MESSAGES_PER_SESSION` | `200` | 세션당 최대 메시지 수 |
| `SAVE_DEBOUNCE_MS` | `2000` | 저장 debounce 시간 (2초) |
| `MAX_OUTPUT_LENGTH` | `500` | output 최대 길이 |
| `MAX_INPUT_LENGTH` | `300` | input 최대 길이 |

---

## 파일 형식

**경로**: `./messages/{sessionId}.json`

```json
{
  "sessionId": "uuid",
  "messages": [...],
  "updatedAt": 1706000000000
}
```

---

## 메시지 타입

### 사용자 메시지

```json
{
  "role": "user",
  "type": "text",
  "content": "메시지 내용",
  "timestamp": 1706000000000
}
```

### 어시스턴트 텍스트

```json
{
  "role": "assistant",
  "type": "text",
  "content": "응답 내용",
  "timestamp": 1706000000000
}
```

### 도구 시작

```json
{
  "role": "assistant",
  "type": "tool_start",
  "toolName": "Read",
  "toolInput": { "file_path": "/path/to/file" },
  "timestamp": 1706000000000
}
```

### 도구 완료

```json
{
  "role": "assistant",
  "type": "tool_complete",
  "toolName": "Read",
  "toolInput": { "file_path": "/path/to/file" },
  "success": true,
  "output": "파일 내용... (500 chars total)",
  "error": null,
  "timestamp": 1706000000000
}
```

### 에러

```json
{
  "role": "system",
  "type": "error",
  "content": "에러 메시지",
  "timestamp": 1706000000000
}
```

### 결과

```json
{
  "role": "system",
  "type": "result",
  "duration": 12.5,
  "inputTokens": 1000,
  "outputTokens": 500,
  "timestamp": 1706000000000
}
```

---

## API

### load(sessionId, options?)

메시지 로드 (페이징 지원)

```javascript
const messages = messageStore.load('session-uuid');
const messages = messageStore.load('session-uuid', { limit: 50, offset: 0 });
```

- 캐시 우선, 없으면 파일에서 로드

### addUserMessage(sessionId, content)

사용자 메시지 추가

```javascript
messageStore.addUserMessage('session-uuid', '안녕하세요');
```

### addAssistantText(sessionId, content)

어시스턴트 텍스트 추가

```javascript
messageStore.addAssistantText('session-uuid', '안녕하세요!');
```

### addToolStart(sessionId, toolName, toolInput)

도구 시작 추가

```javascript
messageStore.addToolStart('session-uuid', 'Read', { file_path: '/path/to/file' });
```

- toolInput 자동 요약

### updateToolComplete(sessionId, toolName, success, result, error)

도구 완료 업데이트

```javascript
messageStore.updateToolComplete('session-uuid', 'Read', true, '파일 내용...', null);
```

- 가장 최근 해당 도구의 tool_start → tool_complete로 업데이트
- output/error 자동 요약

### addError(sessionId, errorMessage)

에러 추가

```javascript
messageStore.addError('session-uuid', '연결이 끊어졌습니다.');
```

### addResult(sessionId, resultData)

결과 정보 추가

```javascript
messageStore.addResult('session-uuid', {
  duration: 12.5,
  inputTokens: 1000,
  outputTokens: 500
});
```

### clear(sessionId)

세션 메시지 초기화

```javascript
messageStore.clear('session-uuid');
```

- 캐시 + 파일 모두 삭제

### saveNow(sessionId)

즉시 저장

```javascript
messageStore.saveNow('session-uuid');
```

### unloadCache(sessionId)

캐시 해제 (시청자 없는 세션에 사용)

```javascript
messageStore.unloadCache('session-uuid');
```

- dirty면 저장 후 캐시 제거

---

## 도구별 Input 요약 규칙

| 도구 | 요약 방식 |
|------|----------|
| Read, Edit, Write, NotebookEdit | `file_path` / `notebook_path`만 |
| Bash | `description` + `command` 첫 줄 |
| Glob, Grep | `pattern` + `path` |
| 기타 | 값 300자 truncate |

---

## 저장 전략

### Debounced 저장

```
메시지 추가 → dirty 표시 → 2초 타이머
                            ↓ (타이머 완료)
                         파일 저장
```

- 연속 메시지 추가 시 타이머 리셋
- 프로세스 종료 시 즉시 저장 (`beforeExit`, `SIGINT`)

### 메시지 수 제한

- 저장 시 최근 200개만 유지
- 오래된 메시지 자동 삭제

---

## 관련 문서

- [claude-manager.md](claude-manager.md) - Claude 세션 관리
- [overview.md](overview.md) - Pylon 개요
