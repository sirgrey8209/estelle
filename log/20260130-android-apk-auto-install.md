# Android APK 자동 설치 기능

## 개요
모바일에서 업데이트 버튼 클릭 시 404 오류 수정 및 APK 다운로드 후 자동 설치 기능 구현

## 문제
- 업데이트 버튼 클릭 시 404 페이지로 이동
- 원인: 코드에서 사용하는 파일명과 실제 GitHub Release 파일명 불일치
  - 코드: `estelle-app.apk` → 실제: `app-release.apk`
  - 코드: `estelle-app.exe` → 실제: `estelle-windows.zip`

## 변경 사항

### 1. 파일명 수정
**파일**: `estelle-app/lib/ui/widgets/settings/app_update_section.dart`

| 플랫폼 | 기존 | 수정 후 |
|--------|------|---------|
| Android | `estelle-app.apk` | `app-release.apk` |
| Windows | `estelle-app.exe` | `estelle-windows.zip` |

### 2. APK 자동 설치 기능 (Android)

#### 추가된 패키지 (`pubspec.yaml`)
```yaml
dio: ^5.4.0
open_filex: ^4.5.0
permission_handler: ^11.3.0
```

#### AndroidManifest 권한 추가
```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

#### FileProvider 설정
- `android/app/src/main/AndroidManifest.xml`: FileProvider 등록
- `android/app/src/main/res/xml/file_paths.xml`: 파일 경로 설정

#### 새로운 파일
- `lib/core/services/apk_installer.dart`: APK 다운로드 및 설치 서비스

### 3. UI 개선
- 다운로드 진행률 표시 (프로그레스바 + %)
- 다운로드 상태 메시지 표시

## 동작 방식

### Android
1. 업데이트 버튼 클릭
2. APK 다운로드 (진행률 표시)
3. 다운로드 완료 → 자동으로 설치 화면 열림
4. 사용자가 설치 확인

### Windows/기타
- 기존 방식 유지 (브라우저에서 파일 다운로드)

## 파일 목록
- `estelle-app/pubspec.yaml`
- `estelle-app/android/app/src/main/AndroidManifest.xml`
- `estelle-app/android/app/src/main/res/xml/file_paths.xml` (신규)
- `estelle-app/lib/core/services/apk_installer.dart` (신규)
- `estelle-app/lib/ui/widgets/settings/app_update_section.dart`
