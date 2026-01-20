require('dotenv').config();
const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;

const wss = new WebSocket.Server({ port: PORT });

// 연결된 클라이언트 관리
// Map<clientId, { ws, deviceId, deviceType, ip, connectedAt }>
const clients = new Map();

// 전체 브로드캐스트
function broadcast(data, excludeClientId = null) {
  const message = JSON.stringify(data);
  clients.forEach((client, clientId) => {
    if (clientId !== excludeClientId && client.ws.readyState === WebSocket.OPEN) {
      client.ws.send(message);
    }
  });
}

// 디바이스 상태 브로드캐스트
function broadcastDeviceStatus() {
  const devices = [];
  clients.forEach((client) => {
    if (client.deviceId) {
      devices.push({
        deviceId: client.deviceId,
        deviceType: client.deviceType || 'unknown',
        connectedAt: client.connectedAt.toISOString()
      });
    }
  });

  broadcast({
    type: 'deviceStatus',
    devices,
    timestamp: new Date().toISOString()
  });

  console.log(`[${new Date().toISOString()}] Device status broadcast: ${devices.length} devices`);
}

wss.on('connection', (ws, req) => {
  const clientId = `client-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const clientIp = req.socket.remoteAddress;

  clients.set(clientId, {
    ws,
    deviceId: null,
    deviceType: null,
    ip: clientIp,
    connectedAt: new Date()
  });

  console.log(`[${new Date().toISOString()}] Client connected: ${clientId} from ${clientIp}`);
  console.log(`[${new Date().toISOString()}] Total clients: ${clients.size}`);

  // 연결 확인 메시지 전송
  ws.send(JSON.stringify({
    type: 'connected',
    clientId,
    message: 'Connected to Estelle Relay'
  }));

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      console.log(`[${new Date().toISOString()}] From ${clientId}:`, data);

      const client = clients.get(clientId);

      // 디바이스 등록 (identify)
      if (data.type === 'identify' || data.type === 'register') {
        if (data.deviceId) {
          client.deviceId = data.deviceId;
          client.deviceType = data.deviceType || 'unknown';
          console.log(`[${new Date().toISOString()}] Device registered: ${data.deviceId} (${client.deviceType})`);

          // 등록 확인 응답
          ws.send(JSON.stringify({
            type: 'registered',
            deviceId: data.deviceId,
            timestamp: new Date().toISOString()
          }));

          // 전체 디바이스 상태 브로드캐스트
          broadcastDeviceStatus();
        }
      }

      // 채팅 메시지 브로드캐스트
      if (data.type === 'chat') {
        const chatMessage = {
          type: 'chat',
          from: client.deviceId || clientId,
          deviceType: client.deviceType,
          message: data.message,
          timestamp: new Date().toISOString()
        };

        // 전체 브로드캐스트 (보낸 사람 포함)
        broadcast(chatMessage);
        console.log(`[${new Date().toISOString()}] Chat from ${client.deviceId}: ${data.message}`);
      }

      // 에코 응답
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

      // 디바이스 목록 요청
      if (data.type === 'getDevices') {
        const devices = [];
        clients.forEach((c) => {
          if (c.deviceId) {
            devices.push({
              deviceId: c.deviceId,
              deviceType: c.deviceType || 'unknown',
              connectedAt: c.connectedAt.toISOString()
            });
          }
        });

        ws.send(JSON.stringify({
          type: 'deviceList',
          devices,
          timestamp: new Date().toISOString()
        }));
      }

      // 업데이트 요청 - pylon에게 전달
      if (data.type === 'update') {
        const targetDeviceId = data.target; // 특정 pylon 지정 가능
        let sent = false;

        clients.forEach((c) => {
          if (c.deviceType === 'pylon' && c.ws.readyState === WebSocket.OPEN) {
            if (!targetDeviceId || c.deviceId === targetDeviceId) {
              c.ws.send(JSON.stringify({
                type: 'update',
                from: client.deviceId || clientId,
                timestamp: new Date().toISOString()
              }));
              sent = true;
              console.log(`[${new Date().toISOString()}] Update request sent to ${c.deviceId}`);
            }
          }
        });

        // 요청자에게 결과 알림
        ws.send(JSON.stringify({
          type: 'updateRequestSent',
          success: sent,
          timestamp: new Date().toISOString()
        }));
      }

      // 배포 요청 - pylon에게 전달 (office-pc 우선)
      if (data.type === 'deployRequest') {
        const targetDeviceId = data.target;
        let sent = false;
        let targetPylon = null;

        // target이 지정되면 해당 pylon에게, 아니면 office-pc 우선
        clients.forEach((c) => {
          if (c.deviceType === 'pylon' && c.ws.readyState === WebSocket.OPEN) {
            if (targetDeviceId && c.deviceId === targetDeviceId) {
              targetPylon = c;
            } else if (!targetDeviceId) {
              if (c.deviceId === 'office-pc' || !targetPylon) {
                targetPylon = c;
              }
            }
          }
        });

        if (targetPylon) {
          targetPylon.ws.send(JSON.stringify({
            type: 'deployRequest',
            from: client.deviceId || clientId,
            timestamp: new Date().toISOString()
          }));
          sent = true;
          console.log(`[${new Date().toISOString()}] Deploy request sent to ${targetPylon.deviceId}`);
        }

        // 요청자에게 결과 알림
        ws.send(JSON.stringify({
          type: 'deployRequestSent',
          success: sent,
          target: targetPylon?.deviceId || null,
          timestamp: new Date().toISOString()
        }));
      }

      // 업데이트 결과 브로드캐스트
      if (data.type === 'updateResult') {
        broadcast({
          type: 'updateResult',
          from: client.deviceId || clientId,
          success: data.success,
          message: data.message,
          timestamp: new Date().toISOString()
        });
        console.log(`[${new Date().toISOString()}] Update result from ${client.deviceId}: ${data.message}`);
      }

      // 배포 알림 브로드캐스트
      if (data.type === 'deploy') {
        broadcast({
          type: 'deployNotification',
          from: client.deviceId || clientId,
          deploy: data.deploy,  // deploy.json 내용
          timestamp: new Date().toISOString()
        });
        console.log(`[${new Date().toISOString()}] Deploy notification from ${client.deviceId}`);
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
    const client = clients.get(clientId);
    const deviceId = client?.deviceId;
    clients.delete(clientId);

    console.log(`[${new Date().toISOString()}] Client disconnected: ${clientId}${deviceId ? ` (${deviceId})` : ''}`);
    console.log(`[${new Date().toISOString()}] Total clients: ${clients.size}`);

    // 디바이스가 등록되어 있었으면 상태 브로드캐스트
    if (deviceId) {
      broadcastDeviceStatus();
    }
  });

  ws.on('error', (err) => {
    console.error(`[${new Date().toISOString()}] Error from ${clientId}:`, err.message);
  });
});

wss.on('listening', () => {
  console.log(`[${new Date().toISOString()}] [Estelle Relay v1] Started on port ${PORT}`);
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
