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
```bash
cd estelle-app
C:\flutter\bin\flutter.bat build apk --release
```
출력: `build/app/outputs/flutter-apk/app-release.apk`

### Windows
```bash
cd estelle-app
C:\flutter\bin\flutter.bat build windows --release
```
출력: `build/windows/x64/runner/Release/`

### Web
```bash
cd estelle-app
C:\flutter\bin\flutter.bat build web --release
```
출력: `build/web/`

---

## GitHub Release 배포

### 수동 배포

1. **APK 빌드**
```bash
cd estelle-app
C:\flutter\bin\flutter.bat build apk --release
```

2. **deploy.json 생성** (임시)
```json
{
  "commit": "<git commit hash>",
  "deployedAt": "2026-01-22T12:00:00Z",
  "relay": "0.0",
  "pylon": "0.0",
  "desktop": "0.0.0",
  "mobile": "0.0.m1"
}
```

3. **GitHub Release 생성/업데이트**
```bash
# 새 릴리스 생성
gh release create deploy --title "Estelle Deploy" --notes "Deployed at YYYY-MM-DD" deploy.json app-release.apk

# 기존 릴리스에 파일 업데이트
gh release upload deploy app-release.apk --clobber
```

4. **로컬 deploy.json 삭제**

### 자동 배포 스크립트
```bash
powershell -File scripts\deploy.ps1
```

스크립트 동작:
1. version.json에서 버전 읽기
2. GitHub Release의 deploy.json과 비교
3. Relay 배포 (Fly.io)
4. APK 빌드 및 업로드
5. deploy.json 업데이트

---

## 버전 관리

### version.json
```json
{
  "relay": 0,
  "pylon": 0,
  "desktop": 0,
  "mobile": 0
}
```

### 버전 형식
| 컴포넌트 | 형식 | 예시 |
|---------|------|------|
| Relay | `{relay}` | `0` |
| Pylon | `{relay}.{pylon}` | `0.0` |
| Desktop | `{relay}.{pylon}.{desktop}` | `0.0.0` |
| Mobile | `{relay}.{pylon}.m{mobile}` | `0.0.m1` |

같은 기본 버전으로 재배포 시 타임코드 추가: `0.0.m1-0122` (MMdd)

---

## 자동 업데이트

### 클라이언트 (Flutter)
- 앱 시작 시 GitHub Release의 deploy.json 확인
- 버전이 다르면 업데이트 알림

### Pylon
- 시작 시 `checkAndUpdate()` 호출
- deploy.json의 commit과 로컬 commit 비교
- 다르면 git pull → npm install → pm2 재시작

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

*Last updated: 2026-01-22*
