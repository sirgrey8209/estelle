# ToolCard

> 도구 실행 결과를 표시하는 카드 컴포넌트

## 위치

`lib/ui/widgets/chat/tool_card.dart`

---

## 역할

- Claude가 도구(Read, Write, Bash 등)를 실행할 때 실행 정보 표시
- 도구 실행 상태(진행중/성공/실패)를 색상으로 구분
- 클릭하면 실행 결과(output)를 펼쳐서 표시

---

## Props

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `message` | `ToolCallMessage` | Y | 도구 실행 메시지 |

### ToolCallMessage 구조

```dart
class ToolCallMessage {
  final String id;
  final String toolName;           // "Read", "Write", "Bash" 등
  final Map<String, dynamic> toolInput;  // 도구 입력 파라미터
  final bool isComplete;           // 완료 여부
  final bool? success;             // 성공 여부 (완료 시)
  final String? output;            // 실행 결과 (최대 1000자)
  final String? error;             // 에러 메시지 (최대 200자)
  final int timestamp;
}
```

---

## 상태 (State)

| 상태 | 타입 | 초기값 | 설명 |
|------|------|--------|------|
| `_expanded` | `bool` | `false` | output 펼침 여부 |

---

## 동작

### 1. 클릭 (Tap)

**트리거**: 카드 영역 탭

**조건**: `output` 또는 `error`가 있을 때만 동작

**처리**:
```dart
onTap: hasOutput || hasError ? () => setState(() => _expanded = !_expanded) : null
```

**결과**:
- `_expanded` 토글
- output 영역 표시/숨김

---

## UI 스펙

### 레이아웃

```
┌─────────────────────────────────────────────┐
│ [상태아이콘] [도구명] [설명]                  │  ← Header (6px padding)
│   ┌──────────────────────────────────┐       │
│   │ 명령어/파일경로                   │       │  ← Command (monospace)
│   └──────────────────────────────────┘       │
├─────────────────────────────────────────────┤
│ 실행 결과 (펼쳤을 때만)                      │  ← Output (maxHeight: 180)
│ - 스크롤 가능                               │
│ - SelectableText                            │
└─────────────────────────────────────────────┘
```

### 상태별 색상 (테두리)

| 상태 | 테두리 색상 | 아이콘 | 설명 |
|------|-------------|--------|------|
| 진행중 (`!isComplete`) | `nord13` (노란색) | `⋯` | 도구 실행 중 |
| 성공 (`success == true`) | `nord14` (초록색) | `✓` | 실행 성공 |
| 실패 (`success == false`) | `nord11` (빨간색) | `✗` | 실행 실패 |

### 색상 상수

```dart
// Nord 색상 팔레트
NordColors.nord0   // 배경 (가장 어두움)
NordColors.nord1   // 카드 배경
NordColors.nord2   // 구분선
NordColors.nord4   // 텍스트 (밝은 회색)
NordColors.nord9   // 도구명 (파란색)
NordColors.nord11  // 에러 (빨간색)
NordColors.nord13  // 진행중 (노란색)
NordColors.nord14  // 성공 (초록색)
```

### 크기

| 요소 | 값 |
|------|-----|
| 테두리 radius | 3px |
| Header padding | 6px horizontal, 3px vertical |
| Command padding | 4px horizontal, 1px vertical |
| 폰트 크기 | 10px |
| Output 최대 높이 | 180px |

---

## 도구별 파싱

`ToolInputParser.parse(toolName, toolInput)` 결과:

| 도구 | desc | cmd |
|------|------|-----|
| Bash | input['description'] | input['command'] |
| Read | "Read file" | input['file_path'] |
| Edit | "Edit file" | input['file_path'] |
| Write | "Write file" | input['file_path'] |
| Glob | "Search in {path}" | input['pattern'] |
| Grep | "Search in {path}" | input['pattern'] |
| WebFetch | "Fetch URL" | input['url'] |
| WebSearch | "Web search" | input['query'] |
| Task | input['description'] | input['prompt'] (100자 제한) |
| TodoWrite | "Update todos" | "{count} items" |
| 기타 | toolName | 첫 번째 string 값 (80자 제한) |

---

## 표시 예시

### Bash 명령어 실행 중

```
┌─────────────────────────────────────────────┐
│ ⋯ Bash List files in directory              │  노란색 테두리
│   ┌──────────────────────────────────┐       │
│   │ ls -la                            │       │
│   └──────────────────────────────────┘       │
└─────────────────────────────────────────────┘
```

### 파일 읽기 성공 (펼친 상태)

```
┌─────────────────────────────────────────────┐
│ ✓ Read Read file                            │  초록색 테두리
│   ┌──────────────────────────────────┐       │
│   │ /path/to/file.txt                 │       │
│   └──────────────────────────────────┘       │
├─────────────────────────────────────────────┤
│ file content line 1                         │
│ file content line 2                         │
│ ...                                         │
└─────────────────────────────────────────────┘
```

### 파일 쓰기 실패

```
┌─────────────────────────────────────────────┐
│ ✗ Write Write file                          │  빨간색 테두리
│   ┌──────────────────────────────────┐       │
│   │ /protected/file.txt               │       │
│   └──────────────────────────────────┘       │
│ ┌─────────────────────────────────────────┐ │
│ │ Permission denied                       │ │  빨간 배경
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## 관련 문서

- [message-bubble.md](./message-bubble.md) - 메시지 버블 (ToolCard 포함)
- [message-list.md](./message-list.md) - 메시지 목록
- [../../system/message-protocol.md](../../system/message-protocol.md) - toolInfo/toolComplete 이벤트
