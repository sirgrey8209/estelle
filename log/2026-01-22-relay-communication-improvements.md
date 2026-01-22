# Relay 통신 개선

## 날짜
2026-01-22

## 작업 내용

### 1. `to` 필드 배열 지원
Relay에서 다중 수신자 지원 추가

**Before:**
```javascript
// 개별 전송 (비효율)
for (const clientId of viewers) {
  this.send({ ...message, to: { deviceId: clientId } });
}
```

**After:**
```javascript
// 배열로 한 번에 전송
this.send({ ...message, to: Array.from(viewers) });

// Relay에서 분배
to: [105, 106, 107]  // 또는 [{ deviceId: 105 }, ...]
```

### 2. deviceId 자동 발급
앱 클라이언트의 deviceId를 Relay에서 자동 발급

**변경:**
- Pylon: 기존대로 deviceId 필수 (1, 2 등 고정 ID)
- App: deviceId 불필요, Relay가 100부터 순차 발급
- 모든 앱 클라이언트 연결 해제 시 카운터 리셋

**메시지 흐름:**
```
App → Relay: { type: 'auth', payload: { deviceType: 'app' } }
Relay → App: { type: 'auth_result', payload: { device: { deviceId: 100, ... } } }
```

### 3. deviceType 변경
- `flutter` → `app`
- 웹/Windows/Android 모두 동일한 타입 사용

### 4. Flutter 잔여 참조 정리
- `estelle-app/README.md` - 프로젝트 설명 갱신
- `estelle-app/web/manifest.json` - 앱 이름 Estelle로 변경
- `estelle-app/test/widget_test.dart` - import 경로 수정

## 수정 파일

| 파일 | 변경 |
|------|------|
| `estelle-relay/src/index.js` | to 배열 지원, deviceId 자동 발급, client_disconnect 알림 |
| `estelle-pylon/src/index.js` | to 배열 전송, deskViewers 캐시 연동 |
| `estelle-app/lib/core/constants/relay_config.dart` | deviceType: 'app', deviceId 제거 |
| `estelle-app/lib/data/services/relay_service.dart` | deviceId 저장/관리 |

## 배포
- Relay: Fly.io 배포 완료
- Pylon: pm2 재시작 완료

---
작성일: 2026-01-22
