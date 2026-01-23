# Settings Screen 작업 현황

## 완료된 작업

### Phase 1: 데이터 모델
- [x] `lib/data/models/deploy_status.dart` - DeployPhase enum, DeployStatus 모델
- [x] `lib/data/models/claude_usage.dart` - Claude 사용량 데이터 모델

### Phase 2: 상태 관리
- [x] `lib/state/providers/settings_provider.dart` - ClaudeUsageNotifier, DeployTrackingNotifier

### Phase 3: Pylon 수정
- [x] `lib/data/services/relay_service.dart` - requestClaudeUsage() 추가
- [x] `estelle-pylon/src/index.js` - claude_usage_request 핸들러 추가

### Phase 4: UI 컴포넌트
- [x] `lib/ui/widgets/settings/claude_usage_card.dart` - 5h/7d 사용량 게이지
- [x] `lib/ui/widgets/settings/deploy_status_card.dart` - 배포 상태 카드
- [x] `lib/ui/widgets/settings/settings_screen.dart` - 설정 화면 메인
- [x] `lib/ui/widgets/settings/settings_dialog.dart` - Desktop 다이얼로그 래퍼

### Phase 5: 레이아웃 통합
- [x] `lib/ui/layouts/desktop_layout.dart` - 설정 버튼 추가, 버전/타임스탬프 표시
- [x] `lib/ui/layouts/mobile_layout.dart` - 3탭 구조 (Desks/Claude/Settings)

### 추가 작업
- [x] `scripts/copy-release.ps1` - EXE 프로세스 관리 (실행 중이면 종료 후 재시작)
- [x] `scripts/generate-build-info.ps1` - Version 파라미터 추가
- [x] `lib/core/constants/relay_config.dart` - appVersion 제거 (BuildInfo로 이동)

## 버전 표시 형식
- Desktop Header: `Estelle Flutter v0.1 0123222300`
  - 버전: BuildInfo.version
  - 타임스탬프: 년도 제외 (MMDDHHmmss), 작은 글씨

## 배포 현황
- Commit: 05704b2
- Version: v0.1
- BuildTime: 20260123231646
- APK: 21.5MB, GitHub Release 업로드 완료
- EXE: 빌드 → 복사 → 재시작 완료

## 완료된 추가 수정
- [x] `scripts/p1-deploy.ps1` - Version, BuildTime 파라미터 전달 수정
- [x] `scripts/build-apk.ps1` - Version 파라미터 추가
- [x] `scripts/build-exe.ps1` - Version 파라미터 추가

## 남은 작업
- [ ] Relay 배포 (선택)
- [ ] Phase 6: deploy_dialog.dart 리팩토링 (공유 Provider 사용)

---
*Last updated: 2026-01-23 23:17*
