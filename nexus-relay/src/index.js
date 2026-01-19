require('dotenv').config();
const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;

const wss = new WebSocket.Server({ port: PORT });

// 연결된 클라이언트 관리
const clients = new Map();

wss.on('connection', (ws, req) => {
  const clientId = `client-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const clientIp = req.socket.remoteAddress;

  clients.set(clientId, { ws, ip: clientIp, connectedAt: new Date() });

  console.log(`[${new Date().toISOString()}] Client connected: ${clientId} from ${clientIp}`);
  console.log(`[${new Date().toISOString()}] Total clients: ${clients.size}`);

  // 연결 확인 메시지 전송
  ws.send(JSON.stringify({
    type: 'connected',
    clientId,
    message: 'Connected to Nexus Relay'
  }));

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      console.log(`[${new Date().toISOString()}] From ${clientId}:`, data);

      // Phase 1: 에코 응답
      if (data.type === 'echo') {
        ws.send(JSON.stringify({
          type: 'echo',
          from: 'relay',
          payload: data.payload,
          timestamp: new Date().toISOString()
        }));
      }

      // ping 처리
      if (data.type === 'ping') {
        ws.send(JSON.stringify({
          type: 'pong',
          timestamp: new Date().toISOString()
        }));
      }

    } catch (err) {
      console.error(`[${new Date().toISOString()}] Invalid message from ${clientId}:`, message.toString());
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Invalid JSON format'
      }));
    }
  });

  ws.on('close', () => {
    clients.delete(clientId);
    console.log(`[${new Date().toISOString()}] Client disconnected: ${clientId}`);
    console.log(`[${new Date().toISOString()}] Total clients: ${clients.size}`);
  });

  ws.on('error', (err) => {
    console.error(`[${new Date().toISOString()}] Error from ${clientId}:`, err.message);
  });
});

wss.on('listening', () => {
  console.log(`[${new Date().toISOString()}] Nexus Relay started on port ${PORT}`);
});

wss.on('error', (err) => {
  console.error(`[${new Date().toISOString()}] Server error:`, err.message);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log(`\n[${new Date().toISOString()}] Shutting down...`);
  wss.close(() => {
    console.log(`[${new Date().toISOString()}] Server closed`);
    process.exit(0);
  });
});
