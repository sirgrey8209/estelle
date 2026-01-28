---
name: estelle-build-deploy
description: Estelle 앱 빌드, 배포, 개발 테스트. 배포/빌드/APK/EXE/릴리즈/업로드/테스트/개발서버/핫리로드 관련 요청 시 사용
allowed-tools: Bash
---

Estelle 앱의 빌드, 배포, 개발 테스트를 수행합니다.

## 인자 처리

`$ARGUMENTS` 값에 따라 작업을 수행하세요 (예: `/estelle-build-deploy deploy`):

- `apk`: APK 빌드
- `exe`: EXE 빌드
- `deploy`: 전체 배포
- `dev`: 웹 개발 서버 실행
- 빈 값: 사용자에게 무엇을 할지 질문

---

## 웹 개발 테스트 (빠른 이터레이션)

Flutter 웹 서버를 **새 터미널 창**에서 포그라운드로 실행:

```powershell
start "" "C:\workspace\estelle\estelle-app\run-dev.bat"
```

실행 후 사용자에게 안내:
- 브라우저에서 `http://localhost:8080` 접속
- **r 키**: Hot Reload (코드 변경 즉시 반영)
- **R 키**: Hot Restart (앱 상태 초기화 + 재시작)
- **q 키**: 서버 종료
- 모바일 테스트: 브라우저 개발자도구에서 모바일 뷰포트로 전환

### Pylon 재시작 (백엔드 변경 시)

```bash
estelle-pylon/restart.bat
```

또는:

```bash
pm2 restart estelle-pylon
```

---

## 빌드 명령어

### APK 빌드 (Android)
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/build-apk.ps1"
```
결과: `estelle-app/build/app/outputs/flutter-apk/app-release.apk`

### EXE 빌드 (Windows)
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/build-exe.ps1"
```
결과: `estelle-app/build/windows/x64/runner/Release/`

### 버전 지정
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/build-apk.ps1" -Version "v0.2"
```

---

## 배포 명령어

### 배포 전 확인
```powershell
git status --porcelain
```
커밋되지 않은 변경사항이 있으면 배포 불가.

### 전체 배포
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/p1-deploy.ps1"
```
git sync → APK 빌드 → EXE 빌드 → GitHub Release 업로드 → Relay 배포 → 릴리즈 폴더 복사

### Relay 스킵 배포
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/p1-deploy.ps1" -SkipRelay
```

---

## 주의사항

- 배포 전 반드시 모든 변경사항을 커밋할 것
- GitHub Release: `sirgrey8209/estelle` 리포의 `deploy` 릴리즈
