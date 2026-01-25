# RequestBar

> 권한 요청과 질문 요청을 표시하는 바 컴포넌트

## 위치

`lib/ui/widgets/requests/request_bar.dart`

---

## 역할

- 대기 중인 권한/질문 요청 표시
- PermissionRequestView 또는 QuestionRequestView 렌더링
- 대기열 카운트 표시

---

## Props

없음 (ConsumerWidget)

---

## 참조하는 Provider

| Provider | 용도 |
|----------|------|
| `currentRequestProvider` | 현재 요청 (첫 번째) |
| `pendingRequestsProvider` | 대기열 (카운트) |
| `selectedItemProvider` | 선택된 대화 |
| `claudeMessagesProvider` | 응답 기록 |
| `relayServiceProvider` | 응답 전송 |

---

## UI 스펙

### 레이아웃

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  [PermissionRequestView 또는 QuestionRequestView]│
│                                                 │
│                 +2 more                         │  ← 대기열 카운트 (2개 이상일 때)
└─────────────────────────────────────────────────┘
```

### 색상

| 요소 | 색상 |
|------|------|
| 배경 | `nord1` |
| 상단 테두리 | `nord2` |
| 대기 카운트 | `nord3` |

### 크기

| 요소 | 값 |
|------|-----|
| padding | 16px |

---

## 동작

### 요청이 없을 때

```dart
if (currentRequest == null) {
  return const SizedBox.shrink();  // 아무것도 표시 안함
}
```

### 권한 응답 (_respondPermission)

**트리거**: PermissionRequestView의 승인/거부 버튼

**처리**:
```dart
1. 응답 기록 추가 (UserResponseMessage)
   - "Write (승인됨)" 또는 "Read (거부됨)"
2. relayService.sendClaudePermission() 호출
3. pendingRequests에서 제거
```

### 질문 응답 (_respondQuestion)

**트리거**: QuestionRequestView의 옵션 선택 또는 제출

**처리**:
```dart
1. 응답 기록 추가 (UserResponseMessage)
   - 단일: "선택한 옵션"
   - 다중: "답변1, 답변2"
2. relayService.sendClaudeAnswer() 호출
3. pendingRequests에서 제거
```

---

## 대기열 시스템

### Provider 구조

```dart
// 현재 요청 (첫 번째)
final currentRequestProvider = Provider<PendingRequest?>((ref) {
  final requests = ref.watch(pendingRequestsProvider);
  return requests.isEmpty ? null : requests.first;
});

// 대기열
class PendingRequestsNotifier extends StateNotifier<List<PendingRequest>> {
  void add(PendingRequest request);
  void removeFirst();
  void updateQuestionAnswer(int questionIndex, String answer);
  void clear();
}
```

### 요청 타입 구분

```dart
switch (currentRequest) {
  PermissionRequest() => PermissionRequestView(...),
  QuestionRequest() => QuestionRequestView(...),
}
```

---

## 메시지 흐름

### 권한 요청 흐름

```
Claude (permission_request)
    ↓
pendingRequestsProvider.add(PermissionRequest)
    ↓
RequestBar 표시
    ↓
사용자 승인/거부
    ↓
claude_permission 메시지 전송
    ↓
pendingRequestsProvider.removeFirst()
    ↓
Claude 계속 실행
```

### 질문 요청 흐름

```
Claude (askQuestion)
    ↓
pendingRequestsProvider.add(QuestionRequest)
    ↓
RequestBar 표시
    ↓
사용자 답변 선택
    ↓
claude_answer 메시지 전송
    ↓
pendingRequestsProvider.removeFirst()
    ↓
Claude 계속 실행
```

---

## 관련 문서

- [permission-request.md](./permission-request.md) - 권한 요청 뷰
- [question-request.md](./question-request.md) - 질문 요청 뷰
- [input-bar.md](./input-bar.md) - 입력 바
- [chat-area.md](./chat-area.md) - 채팅 영역
