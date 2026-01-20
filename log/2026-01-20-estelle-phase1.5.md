# 2026-01-20 Estelle Phase 1.5 구현

## 완료된 작업

### 1. 프로젝트 이름 변경 (Nexus → Estelle)
- 모든 컴포넌트 이름 변경 완료
- Fly.io 앱 이름: `estelle-relay`
- 폴더명: estelle-relay, estelle-pylon, estelle-desktop, estelle-mobile

### 2. Relay 서버 배포
- Fly.io에 estelle-relay 배포 완료
- URL: `wss://estelle-relay.fly.dev`
- 리전: Tokyo (nrt)

### 3. Pylon Task Scheduler
- `scripts/install-service.ps1` 생성
- `scripts/uninstall-service.ps1` 생성
- `scripts/updater.ps1` 생성
- PC 시작 시 자동 실행 설정

### 4. Android APK 빌드
- `.github/workflows/build-android.yml` 생성
- GitHub Releases에 자동 업로드
- 서명 키 설정 완료 (GitHub Secrets)
- 앱 이름: Estelle Mobile

### 5. 버전 관리 시스템
- `version.json` 생성 (현재 v0.0.0)
- `scripts/bump-version.ps1` 생성
- 버전 체계: relay.pylon.desktop / relay.pylon.mN (mobile)

### 6. Deploy 스크립트
- `scripts/deploy.ps1` 생성
- Relay, Pylon, Desktop, Mobile 통합 배포
- deploy.json GitHub Releases 업로드

### 7. Pylon 파일 로깅
- `estelle-pylon/src/logger.js` 생성
- 로그 파일: `estelle-pylon/logs/pylon.log`
- index.js, relayClient.js, localServer.js에 적용

## 생성/수정된 주요 파일
```
nexus/
├── version.json
├── scripts/
│   ├── deploy.ps1
│   ├── bump-version.ps1
│   ├── setup-pc.ps1
├── .github/workflows/
│   └── build-android.yml
├── estelle-relay/
│   └── fly.toml (app = estelle-relay)
├── estelle-pylon/
│   ├── src/logger.js (NEW)
│   ├── src/index.js (logging 적용)
│   ├── src/relayClient.js (logging 적용)
│   ├── src/localServer.js (logging 적용)
│   └── scripts/
│       ├── install-service.ps1
│       ├── uninstall-service.ps1
│       └── updater.ps1
├── estelle-mobile/
│   └── app/src/main/java/.../MainViewModel.kt (relay URL 수정)
└── docs/
    └── pc-setup.md
```

## 알려진 이슈
- 회사 DNS에서 estelle-relay.fly.dev IPv4 전파 지연 → hosts 파일에 임시 추가 필요
