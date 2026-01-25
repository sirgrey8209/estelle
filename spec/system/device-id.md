# Device ID 시스템

> 디바이스 식별 및 인증 체계

---

## 개요

Estelle 시스템에서 각 디바이스를 식별하고 인증하는 체계입니다.

---

## Device ID 유형

### 고정 Device ID (1-99)

Pylon용 고정 ID. Relay에 하드코딩됨.

| ID | 이름 | 아이콘 | 역할 | 설명 |
|----|------|--------|------|------|
| 1 | Selene | 🌙 | home | 집 PC |
| 2 | Stella | ⭐ | office | 회사 PC |

**설정 위치**: `estelle-relay/src/index.js`

```javascript
const DEVICES = {
  1: { name: 'Selene', icon: '🌙', role: 'home', allowedIps: ['*'] },
  2: { name: 'Stella', icon: '⭐', role: 'office', allowedIps: ['*'] },
};
```

### 동적 Device ID (100+)

App 클라이언트용 자동 발급 ID.

- 시작값: `100` (`DYNAMIC_DEVICE_ID_START`)
- Relay 접속 시 자동 발급
- 모든 App 클라이언트 연결 해제 시 카운터 리셋

---

## Device Type

| 타입 | 설명 |
|------|------|
| `pylon` | PC에서 실행되는 백그라운드 서비스 |
| `app` | Flutter 클라이언트 (데스크톱/모바일) |

---

## 인증 흐름

### Pylon 인증

```
1. Pylon → Relay 연결
2. identify 메시지 전송
   { type: 'identify', deviceId: 1, deviceType: 'pylon' }
3. Relay: DEVICES 테이블 확인 + IP 검증
4. 인증 결과 반환
   { type: 'auth_result', payload: { success: true, device: {...} } }
```

### App 인증

```
1. App → Relay 연결
2. auth 메시지 전송
   { type: 'auth', payload: { deviceType: 'app' } }
3. Relay: 동적 ID 발급 (100, 101, ...)
4. 인증 결과 반환
   { type: 'auth_result', payload: { success: true, device: { deviceId: 100, ... } } }
```

---

## IP 제한

고정 디바이스는 IP 제한 가능:

```javascript
{ name: 'Selene', icon: '🌙', role: 'home', allowedIps: ['192.168.1.100'] }
```

- `['*']`: 모든 IP 허용
- `['192.168.1.100']`: 특정 IP만 허용
- 동적 디바이스 (100+): IP 제한 없음

---

## 메시지 라우팅

### from 정보 자동 주입

Relay가 모든 메시지에 `from` 필드 추가:

```json
{
  "type": "some_message",
  "from": {
    "deviceId": 1,
    "deviceType": "pylon",
    "name": "Selene",
    "icon": "🌙"
  },
  ...
}
```

### 라우팅 규칙

| 발신자 | 기본 대상 |
|--------|----------|
| Pylon | 모든 App (non-pylon) |
| App | 모든 Pylon |

### to 옵션

특정 대상 지정:

```json
{ "type": "message", "to": 100 }           // deviceId 100
{ "type": "message", "to": [100, 101] }    // 여러 대상
{ "type": "message", "to": { "deviceId": 1, "deviceType": "pylon" } }
```

### broadcast 옵션

```json
{ "broadcast": "all" }       // 모든 디바이스
{ "broadcast": "pylons" }    // 모든 Pylon
{ "broadcast": "clients" }   // 모든 App
```

---

## 디바이스 상태 조회

### get_devices

```json
{ "type": "get_devices" }
```

### 응답: device_list

```json
{
  "type": "device_list",
  "payload": {
    "devices": [
      {
        "deviceId": 1,
        "deviceType": "pylon",
        "name": "Selene",
        "icon": "🌙",
        "role": "home",
        "connectedAt": "2026-01-25T10:00:00.000Z"
      },
      {
        "deviceId": 100,
        "deviceType": "app",
        "name": "Client 100",
        "icon": "📱",
        "role": "client",
        "connectedAt": "2026-01-25T10:05:00.000Z"
      }
    ]
  }
}
```

### device_status 브로드캐스트

디바이스 연결/해제 시 자동 브로드캐스트:

```json
{
  "type": "device_status",
  "payload": {
    "devices": [...]
  }
}
```

---

## 연결 해제 알림

App 클라이언트 연결 해제 시 Pylon에 알림:

```json
{
  "type": "client_disconnect",
  "payload": {
    "deviceId": 100,
    "deviceType": "app"
  }
}
```

---

## 관련 문서

- [../relay/overview.md](../relay/overview.md) - Relay 서버
- [message-protocol.md](message-protocol.md) - 메시지 프로토콜
