# Mobile Layout

> 모바일용 레이아웃 (너비 < 600px)

## 위치

`lib/ui/layouts/mobile_layout.dart`

---

## 역할

- 3페이지 스와이프 네비게이션
- 탭 바로 페이지 전환
- 커스텀 스와이프 제스처 (dead zone 적용)
- 트리플 탭으로 버그 리포트

---

## 레이아웃 구조

```
┌─────────────────────────────┐
│  ← Estelle    Connected 🌙  │  ← AppBar
├─────────────────────────────┤
│ Workspaces │ Claude │ Settings │ ← TabBar
├─────────────────────────────┤
│                             │
│         PageView            │
│                             │
│   [Page 0] [Page 1] [Page 2]│
│                             │
└─────────────────────────────┘
```

---

## 페이지 구성

| 인덱스 | 이름 | 내용 |
|--------|------|------|
| 0 | Workspaces | `WorkspaceSidebar` |
| 1 | Claude | `ChatArea` 또는 `TaskDetailView` |
| 2 | Settings | `SettingsScreen` |

**초기 페이지**: 1 (Claude)

---

## 상태 (State)

| 상태 | 타입 | 초기값 | 설명 |
|------|------|--------|------|
| `_pageController` | `PageController` | initialPage: 1 | 페이지 컨트롤러 |
| `_currentPage` | `int` | 1 | 현재 페이지 인덱스 |
| `_dragStartX` | `double?` | null | 드래그 시작 X 좌표 |
| `_dragStartPage` | `double?` | null | 드래그 시작 페이지 |
| `_tapCount` | `int` | 0 | 탭 카운트 (트리플 탭용) |
| `_lastTapTime` | `DateTime?` | null | 마지막 탭 시간 |

---

## 동작

### 스와이프 제스처

기본 PageView 스와이프 대신 커스텀 제스처 사용:

```dart
// PageView physics 비활성화
physics: const NeverScrollableScrollPhysics()

// Listener로 커스텀 제스처 처리
Listener(
  onPointerDown: _onPointerDown,
  onPointerMove: _onPointerMove,
  onPointerUp: _onPointerUp,
  child: PageView(...)
)
```

### Dead Zone 적용

민감한 스와이프 방지를 위한 dead zone:

```dart
double _dragToPageOffset(double dragRatio) {
  const deadZone = 0.2;   // 20% 이하는 무시
  const maxZone = 0.5;    // 50%에서 페이지 전환 완료

  if (dragRatio.abs() < deadZone) return 0;

  final sign = dragRatio < 0 ? -1.0 : 1.0;
  final ratio = (dragRatio.abs() - deadZone) / (maxZone - deadZone);
  return sign * ratio.clamp(0.0, 1.0);
}
```

| 드래그 비율 | 페이지 오프셋 |
|------------|---------------|
| 0% ~ 20% | 0 (이동 없음) |
| 20% ~ 50% | 0 ~ 1 (비례) |
| 50% 이상 | 1 (전체 이동) |

### 트리플 탭

400ms 내 3번 탭하면 버그 리포트 다이얼로그:

```dart
void _onTap() {
  final now = DateTime.now();
  if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 400) {
    _tapCount++;
    if (_tapCount >= 3) {
      BugReportDialog.show(context);
      _tapCount = 0;
    }
  } else {
    _tapCount = 1;
  }
  _lastTapTime = now;
}
```

### 로딩 오버레이

페이지별 조건부 로딩 오버레이:

| 페이지 | 오버레이 표시 조건 |
|--------|-------------------|
| 0 (Workspaces) | connecting, loadingWorkspaces |
| 1 (Claude) | connecting, loadingWorkspaces |
| 2 (Settings) | connecting |

---

## AppBar

### 페이지별 타이틀

| 페이지 | 타이틀 |
|--------|--------|
| 0 | "Workspaces" |
| 1 (대화) | "← 💬 대화" |
| 1 (태스크) | "← 📋 태스크" |
| 2 | "⚙ Settings" |

### Actions

- 연결 상태 배지 (Connected/Disconnected)
- Pylon 아이콘들

---

## TabBar (_TabBar)

3개 탭 균등 분할:

| 탭 | 아이콘 | 라벨 |
|----|--------|------|
| 0 | workspaces | Workspaces |
| 1 | chat | Claude |
| 2 | settings | Settings |

### 선택 표시

- 선택된 탭: `nord10` 색상, 하단 2px 테두리, bold
- 미선택 탭: `nord4` 색상

---

## UI 스펙

### 색상

| 요소 | 색상 |
|------|------|
| AppBar 배경 | `nord1` |
| TabBar 배경 | `nord1` |
| TabBar 하단 테두리 | `nord2` |
| 선택된 탭 | `nord10` |
| 미선택 탭 | `nord4` |
| Connected | `nord14` |
| Disconnected | `nord11` |

### 크기

| 요소 | 값 |
|------|-----|
| TabBar 높이 | 40px |
| 탭 아이콘 | 16px |
| 탭 라벨 | 13px |
| 상태 배지 | 11px |

---

## 관련 문서

- [responsive.md](./responsive.md) - 반응형 분기
- [desktop.md](./desktop.md) - 데스크탑 레이아웃
- [../components/workspace-sidebar.md](../components/workspace-sidebar.md) - 워크스페이스 사이드바
- [../components/chat-area.md](../components/chat-area.md) - 채팅 영역
