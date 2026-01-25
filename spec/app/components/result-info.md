# ResultInfo

> Claude 작업 완료 후 결과 정보(시간, 토큰)를 표시하는 컴포넌트

## 위치

`lib/ui/widgets/chat/result_info.dart`

---

## 역할

- Claude 작업 완료 시 소요 시간 표시
- 사용된 토큰 수 표시 (입력 + 출력)

---

## Props

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `message` | `ResultInfoMessage` | Y | 결과 정보 메시지 |

### ResultInfoMessage 구조

```dart
class ResultInfoMessage {
  final String id;
  final int durationMs;        // 소요 시간 (밀리초)
  final int inputTokens;       // 입력 토큰 수
  final int outputTokens;      // 출력 토큰 수
  final int cacheReadTokens;   // 캐시 읽기 토큰 (표시 안함)
  final int timestamp;
}
```

---

## UI 스펙

### 레이아웃

```
┌───────────────────────────┐
│  12.3s · 15.2K tokens     │
└───────────────────────────┘
```

### 색상

| 요소 | 색상 |
|------|------|
| 배경 | `nord1` |
| 숫자 | `nord4` |
| 단위 (s, tokens) | `nord4` (opacity 0.8) |
| 구분점 (·) | `nord3` |

### 크기

| 요소 | 값 |
|------|-----|
| padding | 12px horizontal, 2px vertical |
| border radius | 12px |
| 숫자 크기 | 13px, monospace |
| 단위 크기 | 10px, monospace |

---

## 숫자 포맷팅

`_formatNumber(int n)`:

| 범위 | 포맷 | 예시 |
|------|------|------|
| >= 1,000,000 | `{n}M` | 1.5M |
| >= 1,000 | `{n}K` | 15.2K |
| < 1,000 | 그대로 | 500 |

### 시간 포맷

```dart
(durationMs / 1000).toStringAsFixed(1)  // 예: "12.3"
```

---

## 계산

```dart
totalTokens = inputTokens + outputTokens
```

> 참고: `cacheReadTokens`는 표시하지 않음 (설정 화면에서 누적 사용량으로 표시)

---

## 사용 컨텍스트

`ResultInfoMessage` 타입의 메시지일 때 표시:

```dart
// MessageList에서
switch (message) {
  ResultInfoMessage() => ResultInfo(message: message),
  ...
}
```

---

## 관련 문서

- [working-indicator.md](./working-indicator.md) - 작업 중 인디케이터
- [message-list.md](./message-list.md) - 메시지 목록
- [../../system/message-protocol.md](../../system/message-protocol.md) - result 이벤트
