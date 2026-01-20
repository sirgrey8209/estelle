# estelle-relay - 구현 계획

## 역할

중계 서버 - 모든 기기의 WebSocket 연결을 받아서 메시지 라우팅

## Phase 1 목표

- WebSocket 서버 실행 (포트 443 또는 테스트용 8080)
- 클라이언트 연결 수락
- 연결 상태 로깅
- 에코 응답 (받은 메시지 그대로 돌려주기)

## 기술 스택

- Node.js
- ws (WebSocket 라이브러리)
- dotenv (환경 변수)

## 폴더 구조

```
estelle-relay/
├── PLAN.md
├── package.json
├── .env.example
├── Dockerfile
├── fly.toml
└── src/
    └── index.js
```

## 구현 상세

### 1. WebSocket 서버
```javascript
// 기본 구조
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws, req) => {
  console.log('Client connected:', req.socket.remoteAddress);

  ws.on('message', (message) => {
    // Phase 1: 에코
    ws.send(message);
  });

  ws.on('close', () => {
    console.log('Client disconnected');
  });
});
```

### 2. 환경 변수
```
PORT=8080
NODE_ENV=development
```

### 3. Fly.io 배포 설정
- fly.toml 생성
- Dockerfile 생성
- 443 포트 매핑

## 테스트 방법

```bash
# 로컬 실행
npm start

# WebSocket 테스트 (wscat)
wscat -c ws://localhost:8080
> {"type":"echo","payload":"hello"}
< {"type":"echo","payload":"hello"}
```

## 다음 단계 (Phase 2)

- IP/MAC 인증
- 기기 ID 관리
- 메시지 라우팅 (특정 기기로 전달)
- 오프라인 큐
