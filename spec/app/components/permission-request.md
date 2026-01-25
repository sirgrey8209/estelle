# PermissionRequestView

> 도구 실행 권한 요청을 표시하고 승인/거부를 받는 컴포넌트

## 위치

`lib/ui/widgets/requests/permission_request_view.dart`

---

## 역할

- Claude가 권한이 필요한 도구 실행 시 권한 요청 표시
- 도구 이름과 상세 정보 표시
- 승인/거부 버튼 제공

---

## Props

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `request` | `PermissionRequest` | Y | 권한 요청 정보 |
| `onRespond` | `ValueChanged<String>` | Y | 응답 콜백 ('allow' \| 'deny') |

### PermissionRequest 구조

```dart
class PermissionRequest {
  final String toolUseId;              // 도구 사용 ID
  final String toolName;               // 도구 이름 (Write, Edit, Bash 등)
  final Map<String, dynamic> toolInput; // 도구 입력 파라미터
}
```

---

## UI 스펙

### 레이아웃

```
┌─────────────────────────────────────────────────┐
│ ┌──────────┐                                    │
│ │ 권한 요청 │  Write                             │  ← Header
│ └──────────┘                                    │
│ ┌───────────────────────────────────────────┐   │
│ │ /path/to/file.txt                         │   │  ← Details
│ └───────────────────────────────────────────┘   │
│                                                 │
│ ┌──────┐  ┌──────┐                             │
│ │ 승인  │  │ 거부  │                             │  ← Buttons
│ └──────┘  └──────┘                             │
└─────────────────────────────────────────────────┘
```

### 색상

| 요소 | 색상 |
|------|------|
| 권한 요청 배지 | `nord12` (주황) |
| 배지 텍스트 | `nord0` |
| 도구명 | `nord5`, monospace |
| Details 배경 | `nord0` |
| Details 텍스트 | `nord4`, monospace |
| 승인 버튼 | `nord14` (초록) |
| 거부 버튼 | `nord11` (빨강) |

### 크기

| 요소 | 값 |
|------|-----|
| 배지 padding | 8px horizontal, 2px vertical |
| 배지 radius | 10px |
| Details padding | 8px |
| Details radius | 6px |
| Details maxLines | 3 |
| 버튼 padding | 20px horizontal, 8px vertical |
| 버튼 radius | 6px |

---

## 도구 입력 포맷팅

`_formatToolInput()` 메서드가 toolInput에서 주요 정보 추출:

| 우선순위 | 필드 | 예시 |
|----------|------|------|
| 1 | `command` | `ls -la` (Bash) |
| 2 | `file_path` | `/path/to/file` (Read, Write, Edit) |
| 3 | `pattern` | `**/*.ts` (Glob, Grep) |
| 4 | `url` | `https://example.com` (WebFetch) |
| 5 | 첫 번째 문자열 값 | `key: value` |

---

## 동작

### 승인 버튼 클릭

```dart
onRespond('allow')
```

**결과**:
- `claude_permission` 메시지 전송 (decision: 'allow')
- Claude가 도구 실행 계속

### 거부 버튼 클릭

```dart
onRespond('deny')
```

**결과**:
- `claude_permission` 메시지 전송 (decision: 'deny')
- Claude가 도구 실행 취소

---

## 관련 문서

- [question-request.md](./question-request.md) - 질문 요청 뷰
- [request-bar.md](./request-bar.md) - 요청 바
- [../../system/message-protocol.md](../../system/message-protocol.md) - permission_request, claude_permission
