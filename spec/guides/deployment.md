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

# 3. GitHub Release 업로드 (버전 생략시 기존 버전 유지)
$commit = git rev-parse --short HEAD
.\scripts\upload-release.ps1 -Commit $commit -BuildTime $buildTime

# 버전 변경시
.\scripts\upload-release.ps1 -Commit $commit -Version "v0.2" -BuildTime $buildTime

# 4. 릴리즈 폴더로 복사 (Desktop용)
.\scripts\copy-release.ps1
```

### 통합 배포 (P1)
```powershell
# git sync → build APK/EXE → upload → relay deploy → copy release
.\scripts\p1-deploy.ps1

# 버전 변경시
.\scripts\p1-deploy.ps1 -Version "v0.2"

# Relay 배포 제외
.\scripts\p1-deploy.ps1 -SkipRelay
```

### Relay 배포 (Fly.io)
```powershell
.\scripts\deploy-relay.ps1
```

---

## 4. 스크립트 레퍼런스

### 빌드
| 스크립트 | 설명 |
|---------|------|
| `build-apk.ps1` | APK 빌드 + build_info.dart 생성 |
| `build-exe.ps1` | EXE 빌드 + build_info.dart 생성 |
| `generate-build-info.ps1` | build_info.dart 생성 (빌드 스크립트가 자동 호출) |

### 배포
| 스크립트 | 설명 |
|---------|------|
| `upload-release.ps1` | deploy.json + APK를 GitHub Release에 업로드 |
| `deploy-relay.ps1` | Relay를 Fly.io에 배포 |
| `copy-release.ps1` | EXE를 release 폴더로 복사 (Desktop 배포용) |

### 통합 배포
| 스크립트 | 설명 |
|---------|------|
| `p1-deploy.ps1` | P1(주도 Pylon) 전체 배포: git→build→upload→relay→copy |
| `p2-update.ps1` | P2(다른 Pylon) 업데이트: git→pylon→exe→copy→restart→restore |
| `restart-app.ps1` | Desktop 앱 재시작 (기존 EXE 종료 + 새 EXE 실행) |

### Git 동기화
| 스크립트 | 설명 |
|---------|------|
| `git-sync-p1.ps1` | P1용: fetch → push (로컬이 최신이라고 가정) |
| `git-sync-p2.ps1` | P2용: stash → checkout 특정 커밋 |
| `git-restore-p2.ps1` | P2용: stash 복구 |

### 설정/유틸
| 스크립트 | 설명 |
|---------|------|
| `setup-pc.ps1` | 새 PC 초기 설정 (Node 확인, .env 생성) |
| `install-pm2.ps1` | PM2 설치 및 Pylon 시작 등록 |
| `build-pylon.ps1` | Pylon npm install |

---

## 5. 버전 관리

### deploy.json 구조
```json
{
  "commit": "87b1bed",
  "version": "v0.1",
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
  static const String version = 'v0.2';
  static const String buildTime = '20260123210801';
  static const String commit = '87b1bed';
}
```

---

## 6. 자동 업데이트

### P1 (주도 Pylon)
| 컴포넌트 | 방식 |
|---------|------|
| **Android** | GitHub Release에서 APK 다운로드 |
| **Desktop** | release 폴더에서 EXE 실행 |
| **Web** | 새로고침 |
| **Pylon** | 시작 시 commit 비교 → git pull → pm2 재시작 |
| **Relay** | Fly.io 배포 시 자동 |

### P2 (다른 Pylon)
Pylon 시작 시 또는 수동으로 `p2-update.ps1` 실행:
```
1. git-sync     : stash → checkout 배포 커밋
2. build-pylon  : npm ci
3. build-exe    : Flutter Windows 빌드
4. copy-release : release 폴더로 복사
5. restart-app  : 기존 EXE 종료 → 새 EXE 실행
6. restore      : stash pop (있으면)
```

---

*Last updated: 2026-01-23*
