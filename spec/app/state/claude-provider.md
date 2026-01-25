# Claude Provider

> Claude 메시지와 세션 상태를 관리하는 Provider

## 위치

`lib/state/providers/claude_provider.dart`

---

## 역할

- Claude 메시지 목록 관리
- 스트리밍 텍스트 버퍼 관리
- 권한/질문 요청 대기열 관리
- Claude 상태 (idle/working/permission)
- 세션별 메시지 캐싱

---

## Provider 목록

### claudeMessagesProvider

현재 대화의 메시지 목록

```dart
StateNotifierProvider<ClaudeMessagesNotifier, List<ClaudeMessage>>
```

### claudeStateProvider

Claude 상태

```dart
StateProvider<String>  // 'idle' | 'working' | 'permission'
```

### currentTextBufferProvider

스트리밍 중인 텍스트 버퍼

```dart
StateProvider<String>
```

### isThinkingProvider

생각 중 인디케이터 표시 여부

```dart
StateProvider<bool>
```

### workStartTimeProvider

작업 시작 시간 (경과 시간 표시용)

```dart
StateProvider<DateTime?>
```

### sendingMessageProvider

전송 중인 메시지 (placeholder 표시용)

```dart
StateProvider<String?>
```

### pendingRequestsProvider

대기 중인 권한/질문 요청 목록

```dart
StateNotifierProvider<PendingRequestsNotifier, List<PendingRequest>>
```

### currentRequestProvider

현재 요청 (첫 번째) - derived

```dart
Provider<PendingRequest?>
```

---

## 메시지 타입

`ClaudeMessage` sealed class:

| 타입 | 설명 | 필드 |
|------|------|------|
| `UserTextMessage` | 사용자 입력 | content |
| `AssistantTextMessage` | Claude 응답 | content |
| `ToolCallMessage` | 도구 실행 | toolName, toolInput, isComplete, success, output, error |
| `ResultInfoMessage` | 결과 정보 | durationMs, inputTokens, outputTokens, cacheReadTokens |
| `ErrorMessage` | 에러 | error |
| `UserResponseMessage` | 사용자 응답 | responseType, content |

---

## 메시지 핸들링

### claude_event 처리

| 이벤트 타입 | 처리 |
|-------------|------|
| `userMessage` | 사용자 메시지 추가, sendingMessage 클리어 |
| `text` | currentTextBuffer에 추가 |
| `textComplete` | AssistantTextMessage 추가, 버퍼 클리어 |
| `toolInfo` | ToolCallMessage 추가 (isComplete: false) |
| `toolComplete` | 기존 ToolCallMessage 업데이트 (isComplete: true) |
| `permission_request` | pendingRequests에 추가 |
| `askQuestion` | pendingRequests에 추가 |
| `state` | claudeState 업데이트 |
| `stateUpdate` | isThinking 업데이트 |
| `result` | ResultInfoMessage 추가, 상태 초기화 |
| `error` | ErrorMessage 추가 |

---

## 메시지 캐싱

### 세션별 캐시

```dart
// 메모리 캐시: conversationId → messages
final _sessionMessageCache = <String, List<ClaudeMessage>>{};
```

### 대화 전환 시

```dart
void onConversationSelected(SelectedItem? oldItem, SelectedItem newItem) {
  // 1. 이전 대화 메시지 캐시 저장
  if (oldItem != null) {
    _sessionMessageCache[oldItem.itemId] = List.from(state);
  }

  // 2. 새 대화 캐시 확인
  final cached = _sessionMessageCache[newItem.itemId];
  if (cached != null) {
    state = cached;
    return;
  }

  // 3. 캐시 없으면 Pylon에 히스토리 요청
  state = [];
  _relay.requestHistory(newItem.deviceId, newItem.workspaceId, newItem.itemId);
}
```

---

## 권한/질문 요청

### PendingRequest

```dart
sealed class PendingRequest {
  String get toolUseId;
}

class PermissionRequest extends PendingRequest {
  final String toolUseId;
  final String toolName;
  final Map<String, dynamic> toolInput;
}

class QuestionRequest extends PendingRequest {
  final String toolUseId;
  final List<QuestionItem> questions;
  final Map<int, String> answers;  // 선택된 답변
}
```

### PendingRequestsNotifier

| 메서드 | 설명 |
|--------|------|
| `add(request)` | 요청 추가 |
| `removeFirst()` | 첫 번째 요청 제거 |
| `updateQuestionAnswer(index, answer)` | 질문 답변 업데이트 |
| `clear()` | 모든 요청 제거 |

---

## 상태 흐름

### 메시지 전송

```
1. 사용자 입력
   └── sendingMessageProvider = "입력 텍스트"
   └── claudeStateProvider = 'working'
   └── isThinkingProvider = true
   └── workStartTimeProvider = DateTime.now()

2. userMessage 이벤트 수신
   └── UserTextMessage 추가
   └── sendingMessageProvider = null

3. 스트리밍 텍스트
   └── text 이벤트 → currentTextBufferProvider에 추가
   └── textComplete 이벤트 → AssistantTextMessage 추가, 버퍼 클리어

4. 도구 실행
   └── toolInfo 이벤트 → ToolCallMessage (pending)
   └── toolComplete 이벤트 → ToolCallMessage (complete)

5. 권한 요청 (선택적)
   └── permission_request 이벤트
   └── claudeStateProvider = 'permission'
   └── pendingRequestsProvider에 추가

6. 완료
   └── result 이벤트 → ResultInfoMessage 추가
   └── claudeStateProvider = 'idle'
   └── isThinkingProvider = false
```

---

## 관련 문서

- [workspace-provider.md](./workspace-provider.md) - 워크스페이스 상태
- [relay-provider.md](./relay-provider.md) - Relay 연결
- [../components/request-bar.md](../components/request-bar.md) - 요청 바
- [../../system/message-protocol.md](../../system/message-protocol.md) - 메시지 프로토콜
