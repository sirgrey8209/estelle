# Flutter App 최종화 작업

## 날짜
2026-01-22

## 작업 내용

### 1. 폴더/패키지명 변경
- `estelle-flutter` → `estelle-app`
- `pubspec.yaml`: `name: estelle_flutter` → `name: estelle`
- Android applicationId: `com.nexus.estelle_flutter` → `com.estelle.estelle_app`
- Android label: `estelle_flutter` → `Estelle`
- Kotlin package: `com.nexus.estelle_flutter` → `com.estelle.estelle_app`
- Kotlin 파일 경로: `com/nexus/estelle_flutter/` → `com/estelle/estelle_app/`

### 2. 세션 재개 UI 추가
Desktop App.jsx에는 있었지만 Flutter에 누락되었던 기능 추가:
- `chat_area.dart`의 `_BottomArea` 수정
- `_SessionResumeBar` 위젯 추가
- 조건: `canResume && !hasActiveSession`
- "이어서 작업" → `sendClaudeControl('resume')`
- "새로 시작" → `sendClaudeControl('new_session')`

### 3. Legacy 폴더 삭제
Flutter 마이그레이션 완료로 더 이상 필요 없는 폴더 삭제:
- `estelle-desktop/` (Electron + React)
- `estelle-mobile/` (Android + Kotlin)

### 4. 문서 업데이트
모든 문서에서 `estelle-flutter` → `estelle-app` 반영:
- CLAUDE.md
- docs/architecture.md
- wip/todo.md
- wip/roadmap.md
- wip/next-tasks.md
- log/2026-01-22-flutter-migration.md
- log/2026-01-22-flutter-mobile-ui.md

### 5. wip → log 이동
완료된 작업 문서들 아카이브:
- desktop-ux-redesign.md → log/2026-01-22-desktop-ux-redesign.md
- mobile-relay-fix.md → log/2026-01-22-mobile-relay-fix.md
- auto-update.md → log/2026-01-22-auto-update.md

## 수정된 파일

| 파일 | 변경 |
|------|------|
| `estelle-app/pubspec.yaml` | name 변경 |
| `estelle-app/android/app/build.gradle` | namespace, applicationId 변경 |
| `estelle-app/android/app/src/main/AndroidManifest.xml` | label 변경 |
| `estelle-app/.../MainActivity.kt` | package + 경로 변경 |
| `estelle-app/lib/ui/widgets/chat/chat_area.dart` | 세션 재개 UI 추가 |

## 현재 프로젝트 구조

```
estelle/
├── estelle-relay/       # Relay 서버 (Fly.io)
├── estelle-pylon/       # PC 백그라운드 서비스
├── estelle-app/         # 통합 클라이언트 (Flutter)
├── estelle-shared/      # 공유 타입/상수
├── docs/                # 문서
├── wip/                 # 진행 중 작업
└── log/                 # 완료된 작업 로그
```

---
작성일: 2026-01-22
