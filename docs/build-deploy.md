# 빌드 및 배포 가이드

## 1. 개발 (Web Dev Server)

```powershell
# 새 터미널 창에서 실행 (Hot Reload 지원)
start estelle-app\run-dev.bat
```

- http://localhost:8080 에서 테스트
- `r`: Hot Reload / `R`: Hot Restart / `q`: 종료
- 모바일 테스트: 브라우저 개발자도구 → 모바일 뷰포트

---

## 2. 빌드

### APK 빌드 (Android)
```powershell
.\scripts\build-apk.ps1
```
출력: `estelle-app\build\app\outputs\flutter-apk\app-release.apk`

### EXE 빌드 (Windows)
```powershell
.\scripts\build-exe.ps1
```
출력: `estelle-app\build\windows\x64\runner\Release\`

---

## 3. 배포 (수동)

### 전체 배포 프로세스
```powershell
# 1. BuildTime 생성
$buildTime = Get-Date -Format "yyyyMMddHHmmss"

# 2. APK + EXE 빌드
.\scripts\build-apk.ps1 -BuildTime $buildTime
.\scripts\build-exe.ps1 -BuildTime $buildTime

# 3. GitHub Release 업로드
$commit = git rev-parse --short HEAD
.\scripts\upload-release.ps1 -Commit $commit -Version "0.0.1" -BuildTime $buildTime
```

### Relay 배포 (Fly.io)
```powershell
.\scripts\deploy-relay.ps1
```

---

## 4. 스크립트 레퍼런스

| 스크립트 | 설명 |
|---------|------|
| `build-apk.ps1` | APK 빌드 + build_info.dart 생성 |
| `build-exe.ps1` | EXE 빌드 + build_info.dart 생성 |
| `upload-release.ps1` | deploy.json + APK를 GitHub Release에 업로드 |
| `deploy-relay.ps1` | Relay를 Fly.io에 배포 |
| `generate-build-info.ps1` | build_info.dart 생성 (빌드 스크립트가 자동 호출) |

---

## 5. 버전 관리

### deploy.json 구조
```json
{
  "commit": "87b1bed",
  "version": "0.0.2",
  "buildTime": "20260123210801",
  "deployedAt": "2026-01-23T12:08:37Z"
}
```

### BuildTime
- 형식: `YYYYMMDDHHmmss` (예: `20260123210801`)
- 동일한 배포의 모든 빌드(APK, EXE)에 같은 값 사용
- 앱 업데이트 체크: `로컬 buildTime != 원격 buildTime` → 업데이트 필요

### build_info.dart
빌드 시 자동 생성됨:
```dart
class BuildInfo {
  static const String buildTime = '20260123210801';
  static const String commit = '87b1bed';
}
```

---

## 6. 자동 업데이트

| 컴포넌트 | 방식 |
|---------|------|
| **Android** | GitHub Release에서 APK 다운로드 |
| **Desktop** | 릴리즈 폴더에서 EXE 다운로드 |
| **Web** | 새로고침 |
| **Pylon** | 시작 시 commit 비교 → git pull → pm2 재시작 |
| **Relay** | Fly.io 배포 시 자동 |

---

*Last updated: 2026-01-23*
