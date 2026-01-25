# Settings Screen

> 설정 화면 (모바일 전체화면 / 데스크탑 다이얼로그 공용)

## 위치

`lib/ui/widgets/settings/settings_screen.dart`

---

## 역할

- Claude 사용량 표시
- 배포 기능
- 앱 업데이트 기능

---

## 구성 요소

| 컴포넌트 | 설명 |
|----------|------|
| `ClaudeUsageCard` | Claude API 사용량 카드 |
| `DeploySection` | 배포 섹션 |
| `AppUpdateSection` | 앱 업데이트 섹션 |

---

## 위젯

### SettingsScreen

모바일용 전체 화면 설정

```dart
Container(
  color: NordColors.nord0,
  child: SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(children: [...]),
  ),
)
```

### SettingsContent

다이얼로그/화면 공용 컨텐츠

```dart
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    ClaudeUsageCard(),
    SizedBox(height: 16),
    DeploySection(),
    SizedBox(height: 16),
    AppUpdateSection(),
  ],
)
```

---

## UI 스펙

### 색상

| 요소 | 색상 |
|------|------|
| 배경 | `nord0` |

### 레이아웃

| 요소 | 값 |
|------|-----|
| 패딩 | 16px |
| 섹션 간격 | 16px |

---

## 관련 문서

- [settings-dialog.md](./settings-dialog.md) - 설정 다이얼로그
- [deploy-dialog.md](./deploy-dialog.md) - 배포 다이얼로그
- [../layout/mobile.md](../layout/mobile.md) - 모바일 레이아웃
