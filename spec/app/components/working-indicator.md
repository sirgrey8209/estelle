# WorkingIndicator

> Claude 작업 중 경과 시간을 표시하는 인디케이터

## 위치

`lib/ui/widgets/chat/working_indicator.dart`

---

## 역할

- Claude가 작업 중일 때 경과 시간 표시
- 점멸 애니메이션으로 작업 진행 중임을 표시

---

## Props

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `startTime` | `DateTime` | Y | 작업 시작 시간 |

---

## 상태 (State)

| 상태 | 타입 | 초기값 | 설명 |
|------|------|--------|------|
| `_pulseController` | `AnimationController` | - | 점멸 애니메이션 |
| `_timer` | `Timer` | - | 1초 타이머 |
| `_elapsed` | `int` | `0` | 경과 시간 (초) |

---

## 애니메이션

### 점멸 효과

- **Duration**: 1200ms
- **반복**: reverse로 무한 반복
- **Opacity**: `0.4 + 0.6 * value` = 0.4 ↔ 1.0
- **색상**: `nord13` (노란색)

### 타이머

```dart
_timer = Timer.periodic(const Duration(seconds: 1), (_) {
  setState(() {
    _elapsed = DateTime.now().difference(widget.startTime).inSeconds;
  });
});
```

---

## UI 스펙

### 레이아웃

```
┌─────────────────┐
│  ●  42s         │
└─────────────────┘
 ↑점   ↑경과시간
```

### 색상

| 요소 | 색상 |
|------|------|
| 배경 | `nord1` |
| 점 | `nord13` (노란색) |
| 텍스트 | `nord4` |

### 크기

| 요소 | 값 |
|------|-----|
| padding | 12px horizontal, 2px vertical |
| border radius | 12px |
| 점 크기 | 8x8px |
| 텍스트 크기 | 13px, monospace |

---

## 사용 컨텍스트

`isThinkingProvider`와 `workStartTimeProvider` 조합:

```dart
// ChatArea에서
final isThinking = ref.watch(isThinkingProvider);
final workStartTime = ref.watch(workStartTimeProvider);

if (isThinking && workStartTime != null) {
  return WorkingIndicator(startTime: workStartTime);
}
```

---

## 생명주기

1. **initState**: AnimationController 생성, Timer 시작
2. **매 초**: `_elapsed` 업데이트
3. **dispose**: AnimationController 해제, Timer 취소

---

## 관련 문서

- [streaming-bubble.md](./streaming-bubble.md) - 스트리밍 버블
- [chat-area.md](./chat-area.md) - 채팅 영역
- [input-bar.md](./input-bar.md) - 입력 바 (Stop 버튼)
