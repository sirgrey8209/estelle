# Estelle PC 세팅 가이드

회사 PC와 집 PC를 동일한 환경으로 유지하기 위한 세팅 가이드입니다.

---

## 사전 요구사항

### 1. Node.js 20+
```powershell
winget install OpenJS.NodeJS.LTS
```

### 2. Git
```powershell
winget install Git.Git
```

### 3. GitHub CLI
```powershell
winget install GitHub.cli
```
설치 후 인증:
```powershell
gh auth login
```
- GitHub.com 선택
- HTTPS 선택
- 브라우저로 인증

### 4. Fly CLI
```powershell
powershell -Command "iwr https://fly.io/install.ps1 -useb | iex"
```
설치 후 인증:
```powershell
fly auth login
```

### 5. Flutter SDK
```powershell
# 다운로드 (안정 버전)
curl -L -o "$env:TEMP\flutter.zip" "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"

# C:\flutter에 압축 해제
Expand-Archive "$env:TEMP\flutter.zip" -DestinationPath "C:\"

# PATH에 추가 (영구)
[Environment]::SetEnvironmentVariable('Path', $env:Path + ';C:\flutter\bin', 'User')

# 설치 확인
C:\flutter\bin\flutter.bat doctor
```

> **참고:** 최신 버전은 https://docs.flutter.dev/get-started/install/windows 에서 확인

### 6. Java 17 (Android 빌드용)
```powershell
winget install Microsoft.OpenJDK.17
```

### 7. Android SDK (Android 빌드용)

**방법 1: Android Studio 설치 (권장)**
```powershell
winget install Google.AndroidStudio
```
- 설치 후 Android Studio 한 번 실행하면 SDK 자동 다운로드
- SDK 경로: `%LOCALAPPDATA%\Android\Sdk`

**방법 2: Command-line tools만 설치**
```powershell
# SDK 폴더 생성
mkdir "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools" -Force

# cmdline-tools 다운로드 및 설치
curl -L -o "$env:TEMP\cmdline-tools.zip" "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
Expand-Archive "$env:TEMP\cmdline-tools.zip" -DestinationPath "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools"
Rename-Item "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\cmdline-tools" "latest"

# SDK 컴포넌트 설치
$env:JAVA_HOME = (Get-Item "C:\Program Files\Microsoft\jdk-17*").FullName
& "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="$env:LOCALAPPDATA\Android\Sdk" "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

### 8. 환경변수 설정 (Android 빌드용)
```powershell
# 영구 환경변수 설정
[Environment]::SetEnvironmentVariable('JAVA_HOME', (Get-Item "C:\Program Files\Microsoft\jdk-17*").FullName, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', "$env:LOCALAPPDATA\Android\Sdk", 'User')
```

### 9. SDK 라이선스 수락
```powershell
# licenses 폴더 생성
mkdir "$env:LOCALAPPDATA\Android\Sdk\licenses" -Force

# 라이선스 파일 생성
@"

24333f8a63b6825ea9c5514f83c2829b004d1fee
d56f5187479451eabf01fb78af6dfcb131a6481e
"@ | Set-Content "$env:LOCALAPPDATA\Android\Sdk\licenses\android-sdk-license"

@"

84831b9409646a918e30573bab4c9c91346d8abd
"@ | Set-Content "$env:LOCALAPPDATA\Android\Sdk\licenses\android-sdk-preview-license"
```

---

## 리포지토리 클론

```powershell
git clone https://github.com/sirgrey8209/estelle C:\workspace\estelle
cd C:\workspace\estelle
```

---

## Pylon 설정

### 1. 의존성 설치
```powershell
cd C:\workspace\estelle\estelle-pylon
npm install
```

### 2. 환경변수 설정
```powershell
# 회사 PC
copy .env.stella .env

# 집 PC
copy .env.selene .env
```

### 3. PM2 설정 (프로세스 관리)

```powershell
# PM2 전역 설치 (최초 1회)
npm install -g pm2 pm2-windows-startup

# Pylon 시작
cd C:\WorkSpace\estelle
pm2 start ecosystem.config.js
pm2 save

# Windows 시작 시 자동 실행 (관리자 권한)
pm2-startup install
```

또는 스크립트로 한번에:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-pm2.ps1
```

### 4. PM2 명령어

```powershell
pm2 status                 # 상태 확인
pm2 logs estelle-pylon     # 로그 보기
pm2 restart estelle-pylon  # 재시작
pm2 stop estelle-pylon     # 중지
pm2 delete estelle-pylon   # 삭제
```

---

## Flutter 앱 설정

> estelle-desktop과 estelle-mobile이 estelle-app으로 통합됨

### 1. 의존성 설치
```powershell
cd C:\workspace\estelle\estelle-app
C:\flutter\bin\flutter.bat pub get
```

### 2. 개발 서버 실행 (Web)
```powershell
# 배치 파일로 실행 (Hot Reload 지원)
estelle-app\run-dev.bat

# 또는 직접 실행
cd C:\workspace\estelle\estelle-app
C:\flutter\bin\flutter.bat run -d web-server --web-port=8080
```
- Desktop 테스트: http://localhost:8080
- Mobile 테스트: 브라우저 개발자도구 → 모바일 뷰포트

### 3. Android APK 빌드
```powershell
cd C:\workspace\estelle\estelle-app
C:\flutter\bin\flutter.bat build apk --release
```
출력: `build/app/outputs/flutter-apk/app-release.apk`

---

## 도구 경로 요약

| 도구 | 설치 경로 |
|------|-----------|
| Node.js | `C:\Program Files\nodejs\` |
| Git | `C:\Program Files\Git\` |
| GitHub CLI | `C:\Program Files\GitHub CLI\` |
| Fly CLI | `%USERPROFILE%\.fly\bin\fly.exe` |
| Flutter | `C:\flutter\` |
| Java 17 | `C:\Program Files\Microsoft\jdk-17.*` |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |

---

## 배포 관련

### 배포 실행
Desktop 앱에서 `Deploy` 버튼 클릭 또는:
```powershell
cd C:\workspace\estelle
powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1
```

### 배포 상태 확인
- **Update**: 로컬 버전 < 배포 버전 (업데이트 필요)
- **Deploy**: Git 커밋 > 배포 버전 (새 배포 가능)
- **Synced**: 모든 버전 일치

---

## 문제 해결

### Pylon이 시작되지 않음
```powershell
# PM2 상태 확인
pm2 status

# 로그 확인
pm2 logs estelle-pylon --lines 50

# 수동 실행으로 에러 확인
cd C:\WorkSpace\estelle\estelle-pylon
npm start
```

### gh 명령어가 인식되지 않음
PowerShell에서 전체 경로 사용:
```powershell
& "C:\Program Files\GitHub CLI\gh.exe" --version
```

### fly 명령어가 인식되지 않음
```powershell
& "$env:USERPROFILE\.fly\bin\fly.exe" --version
```

---

## Android 빌드 설정

### Flutter APK 빌드
```powershell
cd C:\workspace\estelle\estelle-app
C:\flutter\bin\flutter.bat build apk --release
```
APK 출력: `build/app/outputs/flutter-apk/app-release.apk`

### Keystore 설정 (릴리스 서명용, 선택)
**파일:** `estelle-app/android/app/estelle-release.keystore` (gitignore됨)

`estelle-app/android/key.properties` 파일 생성:
```properties
storePassword=비밀번호
keyPassword=비밀번호
keyAlias=estelle
storeFile=estelle-release.keystore
```

> **참고:** 현재는 디버그 서명으로 빌드 중

---

## PC 간 동기화 체크리스트

새 PC 세팅 시:

**기본 도구**
- [ ] Node.js 설치
- [ ] Git 설치
- [ ] GitHub CLI 설치 + 인증
- [ ] Fly CLI 설치 + 인증
- [ ] Flutter SDK 설치 (`C:\flutter`)

**Android 빌드 환경**
- [ ] Java 17 설치
- [ ] Android SDK 설치 (Android Studio 또는 cmdline-tools)
- [ ] 환경변수 설정 (JAVA_HOME, ANDROID_HOME)
- [ ] SDK 라이선스 수락

**프로젝트 설정**
- [ ] 리포지토리 클론
- [ ] Pylon npm install + .env 설정
- [ ] PM2 설치 + startup 등록
- [ ] Flutter 앱 flutter pub get
- [ ] 개발 서버 테스트 (`run-dev.bat`)

**Android 빌드 설정**
- [ ] APK 빌드 테스트 (`flutter build apk --release`)
