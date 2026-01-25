# Local Server

> 로컬 WebSocket 서버 모듈

## 위치

`estelle-pylon/src/localServer.js`

---

## 역할

- 로컬 데스크톱 앱 연결 처리
- 동일 PC의 Estelle App과 직접 통신
- Relay 없이 로컬 연결 지원

---

## 클래스: LocalServer

### 생성자

```javascript
const server = new LocalServer(port);
```

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `port` | `number` | 로컬 서버 포트 (기본: 9999) |

---

## 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `port` | `number` | 서버 포트 |
| `wss` | `WebSocketServer` | WebSocket 서버 인스턴스 |
| `clients` | `Set<WebSocket>` | 연결된 클라이언트 목록 |
| `onMessageCallback` | `Function` | 메시지 수신 콜백 |
| `onConnectCallback` | `Function` | 연결 콜백 |
| `getRelayStatus` | `Function` | Relay 연결 상태 조회 함수 |

---

## API

### start()

서버 시작

```javascript
server.start();
```

- 포트에서 WebSocket 서버 시작
- 클라이언트 연결 시 `connected` 메시지 전송

### stop()

서버 중지

```javascript
server.stop();
```

### onMessage(callback)

메시지 수신 콜백 등록

```javascript
server.onMessage((data, ws) => {
  console.log('Received:', data);
});
```

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `data` | `object` | 파싱된 JSON 데이터 |
| `ws` | `WebSocket` | 송신자 WebSocket |

### onConnect(callback)

연결 콜백 등록

```javascript
server.onConnect((ws) => {
  console.log('New client connected');
});
```

### setRelayStatusCallback(callback)

Relay 상태 조회 함수 등록

```javascript
server.setRelayStatusCallback(() => relayClient.isConnected);
```

### broadcast(data)

모든 클라이언트에 브로드캐스트

```javascript
server.broadcast({ type: 'update', data: {...} });
```

- `relay_status`, `pong` 타입은 로깅 제외

### sendRelayStatus(isConnected)

Relay 연결 상태 브로드캐스트

```javascript
server.sendRelayStatus(true);
```

```json
{ "type": "relay_status", "connected": true }
```

---

## 연결 시 메시지

클라이언트 연결 시 자동 전송:

```json
{
  "type": "connected",
  "message": "Connected to Pylon",
  "relayStatus": true
}
```

---

## 이벤트 처리

### connection

```javascript
wss.on('connection', (ws) => {
  // 클라이언트 추가
  // connected 메시지 전송
  // onConnectCallback 호출
});
```

### message

```javascript
ws.on('message', (message) => {
  // JSON 파싱
  // onMessageCallback 호출
});
```

### close

```javascript
ws.on('close', () => {
  // 클라이언트 제거
});
```

### error

```javascript
ws.on('error', (err) => {
  // 에러 로깅
});
```

---

## 로컬 vs Relay 연결

| 구분 | 로컬 | Relay |
|------|------|-------|
| 대상 | 동일 PC | 원격 (모바일 등) |
| 포트 | 9999 | Fly.io |
| 지연 | 없음 | 네트워크 지연 |
| 인증 | 없음 | deviceId 기반 |

---

## 관련 문서

- [overview.md](overview.md) - Pylon 개요
- [../relay/overview.md](../relay/overview.md) - Relay 서버
