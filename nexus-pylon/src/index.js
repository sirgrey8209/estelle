require('dotenv').config();
const RelayClient = require('./relayClient');
const LocalServer = require('./localServer');

// 설정
const RELAY_URL = process.env.RELAY_URL || 'ws://localhost:8080';
const LOCAL_PORT = parseInt(process.env.LOCAL_PORT) || 9000;
const DEVICE_ID = process.env.DEVICE_ID || `pylon-${Date.now()}`;

class Pylon {
  constructor() {
    this.deviceId = DEVICE_ID;
    this.relayClient = null;
    this.localServer = null;
  }

  start() {
    console.log(`[${new Date().toISOString()}] Starting Nexus Pylon...`);
    console.log(`[${new Date().toISOString()}] Device ID: ${this.deviceId}`);
    console.log(`[${new Date().toISOString()}] Relay URL: ${RELAY_URL}`);
    console.log(`[${new Date().toISOString()}] Local Port: ${LOCAL_PORT}`);

    // Relay 클라이언트 초기화
    this.relayClient = new RelayClient(RELAY_URL, this.deviceId);

    // 로컬 서버 초기화 (Desktop 통신용)
    this.localServer = new LocalServer(LOCAL_PORT);
    this.localServer.setRelayClient(this.relayClient);

    // Relay 연결 상태 변경 시 Desktop에 알림
    this.relayClient.onStatusChange((isConnected) => {
      this.localServer.sendRelayStatus(isConnected);
    });

    // Relay에서 메시지 수신 시 Desktop으로 전달
    this.relayClient.onMessage((data) => {
      this.localServer.broadcast({
        type: 'fromRelay',
        data: data
      });
    });

    // Desktop에서 메시지 수신 시 처리
    this.localServer.onMessage((data, ws) => {
      // echo 요청 처리
      if (data.type === 'echo') {
        this.relayClient.send({
          type: 'echo',
          from: this.deviceId,
          payload: data.payload
        });
      }

      // ping 요청 처리
      if (data.type === 'ping') {
        ws.send(JSON.stringify({
          type: 'pong',
          from: 'pylon',
          timestamp: new Date().toISOString()
        }));
      }

      // Relay로 직접 전달
      if (data.type === 'toRelay') {
        this.relayClient.send(data.data);
      }
    });

    // 시작
    this.localServer.start();
    this.relayClient.connect();

    // Graceful shutdown
    process.on('SIGINT', () => {
      console.log(`\n[${new Date().toISOString()}] Shutting down...`);
      process.exit(0);
    });
  }
}

// 직접 실행 시
if (require.main === module) {
  const pylon = new Pylon();
  pylon.start();
}

module.exports = Pylon;
