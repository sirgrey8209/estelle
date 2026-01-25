# StreamingBubble

> 스트리밍 중인 Claude 응답을 표시하는 버블 컴포넌트

## 위치

`lib/ui/widgets/chat/streaming_bubble.dart`

---

## 역할

- Claude가 응답을 스트리밍하는 동안 실시간 텍스트 표시
- 스트리밍 진행 중임을 나타내는 점멸 인디케이터 표시

---

## Props

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `content` | `String` | Y | 현재까지 수신된 스트리밍 텍스트 |

---

## 상태 (State)

| 상태 | 타입 | 설명 |
|------|------|------|
| `_controller` | `AnimationController` | 점멸 애니메이션 |

---

## 애니메이션

### 점멸 인디케이터

- **Duration**: 1초
- **반복**: 무한 반복
- **Opacity**: `0.5 + 0.5 * (1 - value)` = 0.5 ↔ 1.0
- **색상**: `nord8` (밝은 청록)
- **모양**: ● (12px 점)
- **위치**: 우측 하단

---

## UI 스펙

### 레이아웃

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  스트리밍 중인 텍스트...                          │
│  계속 업데이트됨...                              │
│                                            ●    │  ← 점멸 인디케이터
└─────────────────────────────────────────────────┘
```

### 색상

| 요소 | 색상 |
|------|------|
| 배경 | `nord2` |
| 텍스트 | `nord4` |
| 인디케이터 | `nord8` |

### 크기

| 요소 | 값 |
|------|-----|
| padding | 10px |
| border radius | 4px |
| 텍스트 크기 | 13px |
| 텍스트 행간 | 1.4 |
| 인디케이터 크기 | 12px |

---

## 사용 컨텍스트

`currentTextBufferProvider`가 비어있지 않을 때 표시:

```dart
// MessageList에서
final buffer = ref.watch(currentTextBufferProvider);

if (buffer.isNotEmpty) {
  return StreamingBubble(content: buffer);
}
```

---

## 관련 문서

- [message-bubble.md](./message-bubble.md) - 완료된 메시지 버블
- [working-indicator.md](./working-indicator.md) - 작업 중 인디케이터
- [message-list.md](./message-list.md) - 메시지 목록
