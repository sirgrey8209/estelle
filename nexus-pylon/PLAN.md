# nexus-pylon - 구현 계획

## 역할

PC 백그라운드 상주 프로세스
- Relay와 연결 유지
- Desktop과 내부 통신
- (Phase 2+) 파일 접근, 태스크 DB 관리

## Phase 1 목표

- Relay에 WebSocket 연결
- 연결 상태 유지 (재연결 로직)
- Desktop용 localhost WebSocket 서버
- 에코 테스트

## 기술 스택

- Node.js
- ws (WebSocket 라이브러리)
- dotenv (환경 변수)

## 폴더 구조

```
nexus-pylon/
├── PLAN.md
├── package.json
├── .env.example
└── src/
    ├── index.js          # 진입점
    ├── relayClient.js    # Relay 연결 관리
    └── localServer.js    # Desktop 내부 통신
```

## 구현 상세

### 1. Relay 연결 (relayClient.js)
```javascript
const WebSocket = require('ws');

let ws;
const RELAY_URL = process.env.RELAY_URL || 'ws://localhost:8080';

function connect() {
  ws = new WebSocket(RELAY_URL);

  ws.on('open', () => {
    console.log('Connected to Relay');
  });

  ws.on('message', (message) => {
    console.log('From Relay:', message.toString());
    // Desktop으로 전달
  });

  ws.on('close', () => {
    console.log('Disconnected from Relay, reconnecting...');
    setTimeout(connect, 3000);
  });
}
```

### 2. Desktop 내부 통신 (localServer.js)
```javascript
const WebSocket = require('ws');

const localWss = new WebSocket.Server({ port: 9000 });

localWss.on('connection', (ws) => {
  console.log('Desktop connected');

  ws.on('message', (message) => {
    // Relay로 전달 또는 로컬 처리
  });
});
```

### 3. 환경 변수
```
RELAY_URL=ws://localhost:8080
LOCAL_PORT=9000
DEVICE_ID=home-pc
```

## 테스트 방법

```bash
# Relay 먼저 실행 후
npm start

# 로그 확인
# "Connected to Relay" 출력되면 성공
```

## 다음 단계 (Phase 2)

- 시스템 트레이 상주
- 파일 시스템 접근 API
- 태스크 DB (JSON)
- 핑 전송 (슬립 방지)
