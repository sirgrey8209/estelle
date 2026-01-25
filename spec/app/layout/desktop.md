# Desktop Layout

> 데스크탑/태블릿용 레이아웃 (너비 >= 600px)

## 위치

`lib/ui/layouts/desktop_layout.dart`

---

## 역할

- 사이드바 + 메인 영역 2열 레이아웃
- 헤더 표시 (연결 상태, Pylon 목록)
- 로딩 오버레이 관리
- 키보드 단축키 처리

---

## 레이아웃 구조

```
┌─────────────────────────────────────────────────────────────┐
│  ⚙ Estelle Flutter v0.2 0125143000         Connected 🌙⭐  │  ← Header
├──────────────┬──────────────────────────────────────────────┤
│              │                                              │
│  Sidebar     │          Main Area                          │
│  (280px)     │                                              │
│              │  - ChatArea (대화 선택 시)                   │
│  Workspace   │  - TaskDetailView (태스크 선택 시)           │
│  Sidebar     │                                              │
│              │                                              │
│              │                                              │
└──────────────┴──────────────────────────────────────────────┘
```

---

## 구성 요소

### Header (_Header)

| 요소 | 위치 | 내용 |
|------|------|------|
| Settings 버튼 | 좌측 | 설정 다이얼로그 열기 |
| 타이틀 | 좌측 | "Estelle Flutter" |
| 버전 | 좌측 | BuildInfo.version |
| 빌드 시간 | 좌측 | BuildInfo.buildTime (년도 제외) |
| 연결 상태 | 우측 | "Connected" / "Disconnected" |
| Pylon 아이콘 | 우측 | 연결된 Pylon들의 아이콘 |

### Sidebar

- `WorkspaceSidebar` 컴포넌트
- 고정 너비: 280px

### Main Area

- 선택된 항목에 따라 분기:
  - 대화 선택 시: `ChatArea`
  - 태스크 선택 시: `TaskDetailView`

---

## 상태 (State)

| 상태 | 타입 | 설명 |
|------|------|------|
| `_focusNode` | `FocusNode` | 키보드 이벤트 수신용 |

### 참조하는 Provider

| Provider | 용도 |
|----------|------|
| `connectionStateProvider` | 연결 상태 |
| `pylonWorkspacesProvider` | Pylon 목록 |
| `loadingStateProvider` | 로딩 상태 |
| `selectedItemProvider` | 선택된 항목 |

---

## 동작

### 키보드 단축키

| 키 | 동작 |
|----|------|
| `` ` `` (백틱) | 버그 리포트 다이얼로그 열기 |

```dart
void _handleKeyEvent(KeyEvent event) {
  if (event is KeyDownEvent) {
    if (event.logicalKey == LogicalKeyboardKey.backquote) {
      BugReportDialog.show(context);
    }
  }
}
```

### 로딩 오버레이

`loadingState != LoadingState.ready`일 때 전체 화면 오버레이 표시:

- `LoadingState.connecting`: "Connecting..."
- `LoadingState.loadingWorkspaces`: "Loading workspaces..."
- `LoadingState.loadingMessages`: "Loading messages..."

---

## UI 스펙

### 색상

| 요소 | 색상 |
|------|------|
| Header 배경 | `nord1` |
| Header 하단 테두리 | `nord2` |
| 타이틀 | `nord6` |
| 버전 | `nord4` (opacity 0.7) |
| 빌드 시간 | `nord4` (opacity 0.5) |
| Connected | `nord14` (초록) |
| Disconnected | `nord11` (빨강) |
| 상태 배지 배경 | `nord2` |
| Sidebar/Main 구분선 | `nord2` |

### 크기

| 요소 | 값 |
|------|-----|
| Header padding | 24px horizontal, 16px vertical |
| 타이틀 크기 | 20px |
| 버전 크기 | 12px |
| 빌드 시간 크기 | 10px |
| Sidebar 너비 | 280px |

---

## 관련 문서

- [responsive.md](./responsive.md) - 반응형 분기
- [mobile.md](./mobile.md) - 모바일 레이아웃
- [../components/workspace-sidebar.md](../components/workspace-sidebar.md) - 사이드바
- [../components/chat-area.md](../components/chat-area.md) - 채팅 영역
