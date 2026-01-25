# QuestionRequestView

> Claude의 사용자 질문(AskUserQuestion)을 표시하고 응답을 받는 컴포넌트

## 위치

`lib/ui/widgets/requests/question_request_view.dart`

---

## 역할

- Claude가 AskUserQuestion 도구로 질문할 때 표시
- 옵션 버튼 또는 커스텀 입력으로 응답
- 단일/다중 질문 지원

---

## Props

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `request` | `QuestionRequest` | Y | 질문 요청 정보 |
| `onSelectAnswer` | `Function(int, String)` | Y | 옵션 선택 콜백 (다중 질문용) |
| `onSubmit` | `Function(dynamic)` | Y | 최종 제출 콜백 |

### QuestionRequest 구조

```dart
class QuestionRequest {
  final String toolUseId;
  final List<QuestionItem> questions;
  final Map<int, String> answers;  // questionIndex → selected answer
}

class QuestionItem {
  final String question;     // 질문 내용
  final String header;       // 헤더/태그 (12자 제한)
  final List<String> options; // 선택 옵션
  final bool multiSelect;    // 다중 선택 여부
}
```

---

## 상태 (State)

| 상태 | 타입 | 설명 |
|------|------|------|
| `_customController` | `TextEditingController` | 커스텀 답변 입력 |

---

## UI 스펙

### 단일 질문 레이아웃

```
┌─────────────────────────────────────────────────┐
│ ┌────────┐                                      │
│ │ Header │  질문 내용?                           │  ← Question header
│ └────────┘                                      │
│                                                 │
│ ┌──────┐ ┌──────┐ ┌──────┐                     │
│ │옵션1 │ │옵션2 │ │옵션3 │                     │  ← Options (Wrap)
│ └──────┘ └──────┘ └──────┘                     │
│                                                 │
│ ┌───────────────────────────────────────────┐   │
│ │ Or type custom answer...                  │   │  ← Custom input
│ └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### 다중 질문 레이아웃

```
┌─────────────────────────────────────────────────┐
│ ┌────────┐                                      │
│ │Header1 │  첫 번째 질문?                        │
│ └────────┘                                      │
│ ┌──────┐ ┌──────┐                              │
│ │옵션1 │ │옵션2 │                              │  ← 선택하면 하이라이트
│ └──────┘ └──────┘                              │
│                                                 │
│ ┌────────┐                                      │
│ │Header2 │  두 번째 질문?                        │
│ └────────┘                                      │
│ ┌──────┐ ┌──────┐ ┌──────┐                     │
│ │옵션A │ │옵션B │ │옵션C │                     │
│ └──────┘ └──────┘ └──────┘                     │
│                                                 │
│                          ┌─────────────────┐   │
│                          │ 제출 (2/2)      │   │  ← Submit button
│                          └─────────────────┘   │
└─────────────────────────────────────────────────┘
```

### 색상

| 요소 | 색상 |
|------|------|
| Header 배지 | `nord10` (파랑) |
| 배지 텍스트 | `nord6` |
| 질문 텍스트 | `nord5` |
| 옵션 버튼 (기본) | `nord2` |
| 옵션 버튼 (선택됨) | `nord10` |
| 옵션 테두리 (기본) | `nord3` |
| 옵션 테두리 (선택됨) | `nord10` |
| 커스텀 입력 배경 | `nord0` |
| 제출 버튼 | `nord10` |

### 크기

| 요소 | 값 |
|------|-----|
| 배지 padding | 8px horizontal, 2px vertical |
| 배지 radius | 10px |
| 옵션 버튼 padding | 16px horizontal, 8px vertical |
| 옵션 버튼 radius | 6px |
| 옵션 spacing | 8px |
| 커스텀 입력 padding | 14px horizontal, 10px vertical |

---

## 동작

### 단일 질문

**옵션 클릭**: 즉시 제출
```dart
onPressed: () => widget.onSubmit(opt)
```

**커스텀 입력 Enter**: 즉시 제출
```dart
onSubmitted: (_) => _submitCustomAnswer()
```

### 다중 질문

**옵션 클릭**: 선택 상태만 업데이트
```dart
onPressed: () => widget.onSelectAnswer(qIdx, opt)
```

**제출 버튼**: 모든 답변 제출
```dart
onPressed: _submitAllAnswers
// 결과: ['옵션1', '옵션B'] (배열)
```

**제출 버튼 활성화 조건**:
```dart
widget.request.answers.length >= widget.request.questions.length
```

---

## 제출 데이터 형식

| 케이스 | 형식 |
|--------|------|
| 단일 질문 + 옵션 선택 | `"선택한 옵션"` |
| 단일 질문 + 커스텀 | `"커스텀 답변"` |
| 다중 질문 | `["답변1", "답변2"]` |

---

## 관련 문서

- [permission-request.md](./permission-request.md) - 권한 요청 뷰
- [request-bar.md](./request-bar.md) - 요청 바
- [../../system/message-protocol.md](../../system/message-protocol.md) - askQuestion, claude_answer
