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

### Desktop (신규)
- IPC 핸들러: `check-update`, `run-update`
- git checkout → npm install → npm run build → 앱 재시작
- preload.js에 `electronAPI.checkUpdate()`, `electronAPI.runUpdate()` 노출

### Mobile (기존)
- `UpdateChecker` 클래스로 구현
- deploy.json에서 mobile 버전 확인
- APK 다운로드 → FileProvider로 설치 Intent

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
| Desktop | `electron/main.js` | `checkForUpdate()`, `runUpdate()` IPC 핸들러 추가 |
| Desktop | `electron/preload.js` | `checkUpdate`, `runUpdate` API 노출 |

---
작성일: 2026-01-22
