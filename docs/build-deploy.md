# 빌드 및 배포 가이드

## Flutter 앱 빌드

### 개발 서버 (Web)
```bash
cd estelle-app
C:\flutter\bin\flutter.bat run -d web-server --web-port=8080
```
또는 `estelle-app\run-dev.bat` 실행 (Hot Reload 지원)

- Desktop 테스트: http://localhost:8080
- Mobile 테스트: 브라우저 개발자도구 → 모바일 뷰포트

### Android APK

**스크립트 사용 (권장)**
```powershell
.\scripts\build-apk.ps1
# 또는 BuildTime 지정
.\scripts\build-apk.ps1 -BuildTime 20260123150000
```
출력: `estelle-app\build\app\outputs\flutter-apk\app-release.apk`

**수동 빌드**
```bash
cd estelle-app
C:\flutter\bin\flutter.bat build apk --release
```

### Windows

**스크립트 사용 (권장)**
```powershell
.\scripts\build-exe.ps1
# 또는 BuildTime 지정
.\scripts\build-exe.ps1 -BuildTime 20260123150000
```
출력: `estelle-app\build\windows\x64\runner\Release\`

**수동 빌드**
```bash
cd estelle-app
C:\flutter\bin\flutter.bat build windows --release
```

### Web
```bash
cd estelle-app
C:\flutter\bin\flutter.bat build web --release
```
출력: `build/web/`

---

## 빌드 스크립트

### 스크립트 목록

| 스크립트 | 설명 |
|---------|------|
| `generate-build-info.ps1` | build_info.dart 생성 |
| `build-apk.ps1` | APK 빌드 (build_info 포함) |
| `build-exe.ps1` | Windows EXE 빌드 (build_info 포함) |
| `upload-release.ps1` | GitHub Release 업로드 |
| `deploy-relay.ps1` | Fly.io 배포 |

### BuildTime

빌드 시점을 식별하는 타임스탬프 (YYYYMMDDHHmmss 형식)

```
20260123150000 = 2026년 01월 23일 15시 00분 00초
```

- 모든 플랫폼 빌드에 동일한 BuildTime 적용
- `-BuildTime` 파라미터 생략 시 자동 생성
- 앱 업데이트 체크에 사용 (단조 증가 비교)

### build_info.dart

빌드 스크립트가 자동 생성하는 파일:

```dart
// estelle-app/lib/core/constants/build_info.dart
class BuildInfo {
  static const String buildTime = '20260123150000';
  static const String commit = 'abb91c0';
}
```

- 앱 내에서 현재 버전 확인에 사용
- deploy.json의 buildTime과 비교하여 업데이트 판단

---

## GitHub Release 배포

### 수동 배포

1. **APK 빌드**
```bash
cd estelle-app
C:\flutter\bin\flutter.bat build apk --release
```

2. **deploy.json 생성**
```json
{
  "commit": "abb91c0",
  "version": "0.0.m1",
  "buildTime": "20260123150000",
  "deployedAt": "2026-01-23T06:00:00Z"
}
```

3. **GitHub Release에 파일 업로드**
```bash
gh release upload deploy deploy.json --clobber
gh release upload deploy app-release.apk --clobber
```

4. **로컬 deploy.json 삭제**

### 자동 배포 스크립트
```powershell
.\scripts\upload-release.ps1 -Commit abc1234 -Version 1.0.0 -BuildTime 20260123150000
```

스크립트 동작:
1. deploy.json 생성 (commit, version, buildTime, deployedAt)
2. GitHub Release에 deploy.json 업로드
3. APK가 있으면 APK도 업로드
4. 로컬 deploy.json 삭제

---

## 버전 관리

### BuildTime 기반 버전 비교
commit hash 대신 **BuildTime**으로 버전을 비교합니다.

| 필드 | 설명 | 예시 |
|------|------|------|
| `commit` | git commit hash | `abb91c0` |
| `version` | 표시용 버전 | `0.0.m1` |
| `buildTime` | 비교용 타임스탬프 | `20260123150000` |
| `deployedAt` | 배포 시점 (UTC) | `2026-01-23T06:00:00Z` |

### 버전 비교 로직
```
로컬 BuildInfo.buildTime != 원격 deploy.json.buildTime
→ 업데이트 필요
```
**참고**: 로컬이 배포보다 최신인 경우도 있으므로 `<` 대신 `!=` 사용

---

## 자동 업데이트

### 클라이언트 (Flutter)
- 앱 시작 시 GitHub Release의 deploy.json 다운로드
- `BuildInfo.buildTime`과 `deploy.json.buildTime` 비교
- 원격이 더 크면 업데이트 알림 표시
- **Desktop**: 릴리즈 폴더에서 EXE 다운로드 안내
- **Android**: GitHub Release에서 APK 다운로드 안내
- **Web**: 새로고침으로 자동 업데이트

### Pylon
- 시작 시 `checkAndUpdate()` 호출
- deploy.json의 commit과 로컬 commit 비교
- 다르면 git pull → npm install → pm2 재시작
- **주의**: commit이 undefined면 업데이트 스킵

### Relay
- Fly.io 배포 시 자동 업데이트
- `relay_update` 메시지로 수동 트리거 가능

---

## 주의사항

### Android 권한
`android/app/src/main/AndroidManifest.xml`에 필수 권한:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### Windows Developer Mode
Flutter Windows/Web 빌드 시 필요:
```
설정 → 개인 정보 및 보안 → 개발자용 → 개발자 모드 ON
```

### 환경 변수
- `JAVA_HOME`: JDK 17 경로 (Android 빌드용)
- `ANDROID_HOME`: Android SDK 경로

---

*Last updated: 2026-01-23 (BuildTime 기반 버전 관리, 빌드 스크립트 문서화)*
