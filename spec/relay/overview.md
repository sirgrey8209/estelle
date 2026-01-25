# Relay 개요

> 중앙 라우팅 서버 - 순수 메시지 라우터

## 기본 정보

| 항목 | 값 |
|------|-----|
| 런타임 | Node.js |
| 포트 | 8080 |
| 호스팅 | Fly.io |
| URL | wss://estelle-relay.fly.dev |

---

## 핵심 원칙: 순수 라우터

Relay는 메시지 내용을 해석하지 않고 라우팅만 수행:

- `to`, `broadcast` 필드만 확인
- 메시지 페이로드 무시
- 인증, 라우팅, 디바이스 목록만 처리

---

## 디바이스 정의

### 정적 디바이스 (Pylon)

```javascript
const DEVICES = {
  1: { name: 'Selene', icon: '🌙', role: 'home', allowedIps: ['*'] },
  2: { name: 'Stella', icon: '⭐', role: 'office', allowedIps: ['*'] },
};
```

### 동적 디바이스 (App)

- Device ID >= 100은 동적 허용
- 연결 시 자동 발급
- 이름: "Client 100", 아이콘: "📱", role: "client"

---

## 클라이언트 상태

```javascript
clients: Map<clientId, {
  ws,                // WebSocket 연결
  deviceId,          // 디바이스 ID
  deviceType,        // 'pylon' | 'app'
  ip,                // 클라이언트 IP
  connectedAt,       // 연결 시간
  authenticated      // 인증 여부
}>
```

---

## 인증 흐름

### Pylon 인증

```
Client → Relay: { type: 'auth', payload: { deviceId: 1, deviceType: 'pylon' } }
Relay → Client: { type: 'auth_result', payload: { success: true, device: {...} } }
Relay → All: { type: 'device_status', payload: { devices: [...] } }
```

- `deviceId` 필수
- DEVICES에 정의된 ID만 허용
- IP 체크 (현재 모두 '*')

### App 인증

```
Client → Relay: { type: 'auth', payload: { deviceType: 'app' } }
Relay → Client: { type: 'auth_result', payload: { success: true, device: { deviceId: 100, ... } } }
```

- `deviceId` 자동 발급 (100부터 증가)
- 모든 앱 연결 해제 시 카운터 리셋

---

## 라우팅 규칙

### 1. to 필드

특정 디바이스로 전송

```javascript
// 단일 대상
{ to: { deviceId: 1 } }
{ to: 1 }  // 숫자만 가능

// 다중 대상
{ to: [100, 101, 102] }
{ to: [{ deviceId: 100 }, { deviceId: 101 }] }
```

### 2. broadcast 필드

브로드캐스트

| 값 | 대상 |
|----|------|
| `'all'` | 모든 인증된 클라이언트 |
| `'pylons'` | Pylon만 |
| `'clients'` | Pylon 제외 모든 클라이언트 |
| `'app'` | deviceType === 'app' |

### 3. 기본 라우팅

to, broadcast 없을 때:

| 발신자 | 수신자 |
|--------|--------|
| Pylon | 모든 클라이언트 (Pylon 제외) |
| 클라이언트 | 모든 Pylon |

---

## Relay 내부 메시지

### auth

인증 요청

### auth_result

인증 결과

### get_devices / device_list

연결된 디바이스 목록

### ping / pong

연결 확인

### relay_update

Relay 자체 업데이트 (Pylon만 가능)

### relay_version

Relay 버전 (commit hash) 확인

### device_status

디바이스 연결/해제 시 브로드캐스트

### client_disconnect

클라이언트 연결 해제 알림 (Pylon에게만)

---

## from 필드 주입

모든 라우팅 메시지에 발신자 정보 자동 주입:

```javascript
data.from = {
  deviceId: 1,
  deviceType: 'pylon',
  name: 'Selene',
  icon: '🌙'
};
```

---

## 자동 업데이트

### 시작 시

1. 로컬 commit 확인 (`git rev-parse --short HEAD`)
2. GitHub Release에서 `deploy.json` fetch
3. 버전 불일치 시:
   - `git fetch origin`
   - `git checkout {commit}`
   - `npm install`
   - 프로세스 재시작

### relay_update 요청

Pylon이 `relay_update` 메시지 전송 시:
1. 업데이트 체크 및 적용
2. `relay_update_result` 응답
3. 업데이트 적용 시 `relay_restarting` 브로드캐스트 후 재시작

---

## 연결 관리

### 연결 시

```
1. clientId 발급 (client-{timestamp}-{random})
2. clients Map에 등록
3. 'connected' 메시지 전송
```

### 연결 해제 시

```
1. clients Map에서 제거
2. 인증된 클라이언트였으면:
   - device_status 브로드캐스트
   - 클라이언트(비-Pylon)면 client_disconnect 전송 (Pylon에게)
3. 모든 앱 클라이언트 해제 시 ID 카운터 리셋
```

---

## 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `PORT` | `8080` | 서버 포트 |

---

## 관련 문서

- [../system/architecture.md](../system/architecture.md) - 시스템 아키텍처
- [../system/message-protocol.md](../system/message-protocol.md) - 메시지 프로토콜
- [../pylon/overview.md](../pylon/overview.md) - Pylon 개요
