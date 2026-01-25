# Settings Dialog

> 데스크탑용 설정 다이얼로그

## 위치

`lib/ui/widgets/settings/settings_dialog.dart`

---

## 역할

- 데스크탑에서 설정 화면을 다이얼로그로 표시
- `SettingsContent` 위젯 재사용

---

## 호출 방법

```dart
SettingsDialog.show(context);
```

---

## 구조

```
┌─────────────────────────────────────┐
│  ⚙ Settings                    [X]  │  ← Header
├─────────────────────────────────────┤
│                                     │
│  [SettingsContent]                  │  ← 스크롤 가능
│    - ClaudeUsageCard               │
│    - DeploySection                 │
│    - AppUpdateSection              │
│                                     │
└─────────────────────────────────────┘
```

---

## UI 스펙

### 크기

| 요소 | 값 |
|------|-----|
| 다이얼로그 너비 | 400px |
| 최대 높이 | 600px |
| 헤더 패딩 | 20px × 16px |
| 컨텐츠 패딩 | 20px |

### 색상

| 요소 | 색상 |
|------|------|
| 배경 | `nord1` |
| 헤더 아이콘 | `nord4` |
| 헤더 타이틀 | `nord5` |
| 헤더 하단 테두리 | `nord2` |
| 닫기 버튼 | `nord4` |

### 스타일

| 요소 | 값 |
|------|-----|
| 모서리 반경 | 12px |
| 타이틀 폰트 | 18px, 600 |
| 아이콘 크기 | 20px |

---

## 관련 문서

- [settings-screen.md](./settings-screen.md) - 설정 화면 내용
- [../layout/desktop.md](../layout/desktop.md) - 데스크탑 레이아웃
