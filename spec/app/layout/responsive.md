# Responsive Layout

> 화면 크기에 따른 반응형 레이아웃 분기

## 위치

- `lib/ui/layouts/responsive_layout.dart`
- `lib/core/utils/responsive_utils.dart`

---

## 역할

- 화면 너비에 따라 Desktop/Mobile 레이아웃 분기
- 반응형 breakpoint 정의

---

## Breakpoint 정의

```dart
class ResponsiveUtils {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double sidebarWidth = 260;
}
```

| 범위 | 분류 | 레이아웃 |
|------|------|----------|
| < 600px | Mobile | MobileLayout |
| >= 600px | Desktop/Tablet | DesktopLayout |
| >= 900px | Desktop | DesktopLayout |

---

## 분기 로직

### ResponsiveLayout

```dart
class ResponsiveLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (ResponsiveUtils.shouldShowSidebar(context)) {
      return const DesktopLayout();
    }
    return const MobileLayout();
  }
}
```

### shouldShowSidebar

```dart
static bool shouldShowSidebar(BuildContext context) {
  if (forceMobileLayout) return false;  // 테스트용 강제 모바일
  return MediaQuery.of(context).size.width >= mobileBreakpoint;
}
```

---

## 유틸리티 메서드

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `isMobile(context)` | `bool` | < 600px |
| `isTablet(context)` | `bool` | 600px ~ 900px |
| `isDesktop(context)` | `bool` | >= 900px |
| `shouldShowSidebar(context)` | `bool` | >= 600px |

---

## 강제 모바일 모드

테스트용으로 모바일 레이아웃 강제:

```dart
// Web URL 파라미터로 설정
// http://localhost:8080/?mobile=true

ResponsiveUtils.forceMobileLayout = true;
```

`main.dart`에서 URL 파라미터 확인:

```dart
void main() {
  // Web: ?mobile=true 파라미터 확인
  if (kIsWeb) {
    final uri = Uri.base;
    if (uri.queryParameters['mobile'] == 'true') {
      ResponsiveUtils.forceMobileLayout = true;
    }
  }
  runApp(ProviderScope(child: EstelleApp()));
}
```

---

## 관련 문서

- [desktop.md](./desktop.md) - 데스크탑 레이아웃
- [mobile.md](./mobile.md) - 모바일 레이아웃
