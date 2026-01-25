# InputBar

> 메시지 입력창 컴포넌트

## 위치

`lib/ui/widgets/chat/input_bar.dart`

---

## 역할

- 사용자 메시지 입력
- 전송 버튼 / 정지 버튼 표시
- 플랫폼별 Enter 키 동작 처리

---

## Props

없음 (ConsumerStatefulWidget)

---

## 상태 (State)

| 상태 | 타입 | 초기값 | 설명 |
|------|------|--------|------|
| `_controller` | `TextEditingController` | - | 텍스트 컨트롤러 |
| `_focusNode` | `FocusNode` | - | 포커스 노드 |
| `_hasText` | `bool` | `false` | 입력 텍스트 존재 여부 |

### 참조하는 Provider

| Provider | 용도 |
|----------|------|
| `selectedItemProvider` | 현재 선택된 대화 |
| `selectedWorkspaceProvider` | 현재 워크스페이스 |
| `claudeStateProvider` | Claude 상태 (idle/working/permission) |
| `sendingMessageProvider` | 전송 중 placeholder |
| `isThinkingProvider` | 생각 중 표시 |
| `workStartTimeProvider` | 작업 시작 시간 |
| `relayServiceProvider` | 메시지 전송 |

---

## 동작

### 1. 메시지 전송 (_send)

**트리거**:
- Send 버튼 클릭
- Enter 키 (데스크탑만)

**조건**:
- 텍스트가 비어있지 않음
- 대화가 선택되어 있음
- Claude가 working 상태가 아님

**처리**:
```dart
1. sendingMessageProvider 설정 (placeholder 표시)
2. relayService.sendClaudeMessage() 호출
3. claudeStateProvider = 'working'
4. isThinkingProvider = true
5. workStartTimeProvider = DateTime.now()
6. 입력창 클리어
```

### 2. 작업 정지 (_stop)

**트리거**: Stop 버튼 클릭

**처리**:
```dart
relayService.sendClaudeControl(deviceId, workspaceId, conversationId, 'stop')
```

### 3. 키보드 처리

**데스크탑 (너비 >= 600px)**:
- `Enter`: 전송
- `Shift+Enter`: 줄바꿈
- `Ctrl+Enter`: 줄바꿈

**모바일 (너비 < 600px)**:
- `Enter`: 줄바꿈 (기본 동작)

---

## UI 스펙

### 레이아웃

```
┌─────────────────────────────────────────────────┐
│  ┌───────────────────────────────┐   ┌──────┐  │
│  │                               │   │ Send │  │
│  │  Type a message...            │   │      │  │
│  │  (최대 6줄)                   │   │ Stop │  │
│  └───────────────────────────────┘   └──────┘  │
└─────────────────────────────────────────────────┘
```

### 크기

| 요소 | 값 |
|------|-----|
| 전체 padding | 12px horizontal, 8px vertical |
| TextField 최대 높이 | 150px (약 6줄) |
| TextField border radius | 6px |
| 버튼 padding | 16px horizontal, 10px vertical |
| 버튼 border radius | 6px |

### 색상

| 요소 | 색상 |
|------|------|
| 배경 | `nord1` |
| 상단 테두리 | `nord2` |
| 입력창 배경 | `nord0` |
| 입력창 테두리 (기본) | `nord2` |
| 입력창 테두리 (포커스) | `nord9` |
| Placeholder | `nord3` |
| 입력 텍스트 | `nord5` |
| Send 버튼 | `nord10` (파랑) |
| Stop 버튼 | `nord11` (빨강) |
| 버튼 텍스트 | `nord6` |

### 버튼 상태

| 상태 | 버튼 |
|------|------|
| `claudeState == 'working'` | Stop (빨간색) |
| `claudeState != 'working'` | Send (파란색) |
| `!_hasText` | Send 비활성화 |

---

## 입력창 속성

```dart
TextField(
  controller: _controller,
  focusNode: _focusNode,
  enabled: true,              // 항상 활성화 (미리 입력 가능)
  maxLines: null,             // 동적 높이
  minLines: 1,
  scrollPhysics: BouncingScrollPhysics(),
  ...
)
```

---

## 관련 문서

- [chat-area.md](./chat-area.md) - 채팅 영역 (InputBar 포함)
- [request-bar.md](./request-bar.md) - 권한/질문 요청 바
- [../../system/message-protocol.md](../../system/message-protocol.md) - claude_send 메시지
