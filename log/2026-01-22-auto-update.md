# 자동 업데이트 기능

## 상태: DONE

## 개요
모든 컴포넌트가 GitHub releases의 `deploy.json`을 참조하여 자동 업데이트를 수행합니다.

## deploy.json 형식
```json
{
  "commit": "abc1234",
  "deployedAt": "2026-01-22T10:00:00Z",
  "relay": "1.0.0",
  "pylon": "1.0.0",
  "desktop": "1.0.0",
  "mobile": "1.0.m1"
}
```

## 컴포넌트별 구현

### Pylon (기존)
- 시작 시 `checkAndUpdate()` 호출
- deploy.json의 commit과 로컬 commit 비교
- 다르면 git checkout → npm install → 재시작
- 원격 업데이트 명령 수신 가능 (`type: 'update'`)

### Relay (신규)
- 시작 시 `checkAndUpdate()` 호출
- Pylon에서 `relay_update` 메시지로 업데이트 트리거 가능
- `relay_version` 메시지로 현재 버전 확인 가능
- 업데이트 시 모든 클라이언트에 `relay_restarting` 알림

### Client - Flutter (신규)

> ⚠️ estelle-desktop과 estelle-mobile이 estelle-app로 통합됨

**Windows**:
- 빌드: `flutter build windows`
- 업데이트: deploy.json에서 버전 확인 → 릴리즈 다운로드 → 설치

**Android**:
- 빌드: `flutter build apk`
- 업데이트: deploy.json에서 버전 확인 → APK 다운로드 → 설치 Intent

**Web**:
- 빌드: `flutter build web`
- 배포: 정적 파일 서빙 (Vercel/Netlify 등)

### (Deprecated) Desktop - Electron
- estelle-app로 마이그레이션됨

### (Deprecated) Mobile - Kotlin
- estelle-app로 마이그레이션됨

## 메시지 타입

| 타입 | 방향 | 설명 |
|------|------|------|
| `relay_update` | Client → Relay | Relay 업데이트 요청 (Pylon만 가능) |
| `relay_update_result` | Relay → Client | 업데이트 결과 |
| `relay_version` | Client → Relay | Relay 버전 확인 |
| `relay_version_result` | Relay → Client | 현재 commit |
| `relay_restarting` | Relay → All | 재시작 알림 |
| `deployNotification` | → All | 배포 알림 (Mobile 업데이트 체크 트리거) |

## 수정된 파일

| 컴포넌트 | 파일 | 변경 |
|---------|------|------|
| Relay | `src/index.js` | `checkAndUpdate()`, `handleRelayUpdate()`, `getLocalCommit()` 추가 |
| ~~Desktop~~ | ~~`electron/main.js`~~ | ~~→ estelle-app로 마이그레이션됨~~ |
| Flutter | `lib/` | 통합 클라이언트 (Windows/Android/Web) |

---

## Flutter 빌드 명령어

```bash
# Windows
cd estelle-app
flutter build windows

# Android APK
flutter build apk

# Web
flutter build web

# 개발 서버 (Web)
flutter run -d web-server --web-port=8080
```

---
작성일: 2026-01-22
수정일: 2026-01-22 (Flutter 마이그레이션 반영)
