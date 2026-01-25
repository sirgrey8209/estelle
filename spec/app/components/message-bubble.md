# MessageBubble

> 채팅 메시지를 표시하는 버블 컴포넌트

## 위치

`lib/ui/widgets/chat/message_bubble.dart`

---

## 역할

- 사용자/어시스턴트 메시지 표시
- 에러 메시지 표시
- 권한/질문 응답 표시
- 전송 중 상태 표시

---

## Factory 생성자

### MessageBubble.user

사용자가 입력한 메시지

```dart
factory MessageBubble.user({required String content})
```

| 속성 | 값 |
|------|-----|
| 배경색 | `nord3` |
| 테두리 | `nord10` (왼쪽 2px) |
| 텍스트 | `nord6`, 13px |

### MessageBubble.sending

전송 중인 메시지 (placeholder)

```dart
factory MessageBubble.sending({required String content})
```

| 속성 | 값 |
|------|-----|
| 배경색 | `nord2` |
| 테두리 | `nord3` (왼쪽 2px) |
| 텍스트 | `nord5`, 13px, opacity 0.7 |
| 추가 | "전송 중..." 텍스트 |

### MessageBubble.assistant

Claude의 응답 메시지

```dart
factory MessageBubble.assistant({required String content})
```

| 속성 | 값 |
|------|-----|
| 배경색 | 투명 |
| 테두리 | 없음 |
| 텍스트 | `nord4`, 13px |

### MessageBubble.error

에러 메시지

```dart
factory MessageBubble.error({required String error})
```

| 속성 | 값 |
|------|-----|
| 배경색 | `nord1` |
| 테두리 | `nord11` (왼쪽 2px) |
| 텍스트 | `nord11`, 13px |
| 아이콘 | 경고 이모지 |

### MessageBubble.response

사용자의 권한/질문 응답

```dart
factory MessageBubble.response({
  required String responseType,  // 'permission' | 'question'
  required String content,
})
```

| 속성 | 값 |
|------|-----|
| 배경색 | `nord2` |
| 텍스트 | monospace 12px (권한), 일반 12px (질문) |
| 승인 색상 | `nord14` (초록) |
| 거부 색상 | `nord11` (빨강) |

---

## UI 스펙

### 공통 레이아웃

```dart
Align(
  alignment: Alignment.centerLeft,  // 항상 왼쪽 정렬
  child: Container(
    constraints: BoxConstraints(
      maxWidth: screenWidth * 0.9,  // 화면 너비의 90%
    ),
    padding: EdgeInsets.symmetric(
      horizontal: hasBackground ? 10 : 0,
      vertical: hasBackground ? 6 : 0,
    ),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(4),
      border: borderColor != null
          ? Border(left: BorderSide(color: borderColor, width: 2))
          : null,
    ),
    child: child,
  ),
)
```

### 텍스트 스타일

| 요소 | 크기 | 행간 |
|------|------|------|
| 메시지 본문 | 13px | 1.4 |
| 전송 중 라벨 | 11px | - |
| 응답 텍스트 | 12px | - |

### 색상 참조 (Nord)

| 색상 | 용도 |
|------|------|
| `nord0` | 가장 어두운 배경 |
| `nord1` | 카드 배경 |
| `nord2` | 전송 중 배경 |
| `nord3` | 사용자 버블 배경 |
| `nord4` | 어시스턴트 텍스트 |
| `nord5` | 밝은 텍스트 |
| `nord6` | 가장 밝은 텍스트 |
| `nord10` | 사용자 테두리 (파랑) |
| `nord11` | 에러 (빨강) |
| `nord14` | 승인 (초록) |

---

## 사용 예시

```dart
// 사용자 메시지
MessageBubble.user(content: '안녕하세요')

// 어시스턴트 응답
MessageBubble.assistant(content: '안녕하세요! 무엇을 도와드릴까요?')

// 에러
MessageBubble.error(error: 'Rate limit exceeded')

// 권한 응답
MessageBubble.response(
  responseType: 'permission',
  content: 'Write (승인됨)',
)
```

---

## 관련 문서

- [streaming-bubble.md](./streaming-bubble.md) - 스트리밍 중 버블
- [tool-card.md](./tool-card.md) - 도구 실행 카드
- [message-list.md](./message-list.md) - 메시지 목록
