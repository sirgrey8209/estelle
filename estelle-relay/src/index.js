/**
 * Estelle Relay - v1 (Pure Router)
 * 순수 중계기: 인증 + 라우팅만 담당
 * 메시지 내용은 해석하지 않음
 */

require('dotenv').config();
const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;

// ============ 디바이스 정의 ============
const DEVICES = {
  1: { name: 'Selene', icon: '🌙', role: 'home', allowedIps: ['*'] },
  2: { name: 'Stella', icon: '⭐', role: 'office', allowedIps: ['*'] },
};

// 동적 디바이스 ID 범위 (100 이상은 동적 허용)
const DYNAMIC_DEVICE_ID_START = 100;

// ============ 상태 저장소 ============
const clients = new Map();  // clientId -> ClientInfo

// ============ 유틸리티 ============

function log(message) {
  console.log(`[${new Date().toISOString()}] ${message}`);
}

function getClientIp(req) {
  return req.headers['x-forwarded-for']?.split(',')[0]?.trim()
    || req.socket.remoteAddress
    || 'unknown';
}

function getDeviceInfo(deviceId) {
  return DEVICES[deviceId] || { name: `Device ${deviceId}`, icon: '💻', role: 'unknown' };
}

// ============ 인증 ============

function authenticateDevice(deviceId, deviceType, ip) {
  const device = DEVICES[deviceId];

  if (device) {
    const allowed = device.allowedIps;
    if (allowed.includes('*') || allowed.includes(ip)) {
      return { success: true };
    }
    return { success: false, error: `IP not allowed: ${ip}` };
  }

  // 동적 디바이스 ID 허용 (100 이상)
  if (deviceId >= DYNAMIC_DEVICE_ID_START) {
    return { success: true };
  }

  return { success: false, error: `Unknown device: ${deviceId}` };
}

// ============ 라우팅 ============

function sendTo(clientId, message) {
  const client = clients.get(clientId);
  if (client && client.ws.readyState === WebSocket.OPEN) {
    client.ws.send(JSON.stringify(message));
    return true;
  }
  return false;
}

function sendToDevice(deviceId, deviceType, message) {
  let sent = false;
  clients.forEach((client, clientId) => {
    if (client.deviceId === deviceId && client.authenticated) {
      if (!deviceType || client.deviceType === deviceType) {
        sendTo(clientId, message);
        sent = true;
      }
    }
  });
  return sent;
}

function broadcast(message, excludeClientId = null) {
  clients.forEach((client, clientId) => {
    if (clientId !== excludeClientId && client.authenticated && client.ws.readyState === WebSocket.OPEN) {
      client.ws.send(JSON.stringify(message));
    }
  });
}

function broadcastToType(deviceType, message, excludeClientId = null) {
  clients.forEach((client, clientId) => {
    if (clientId !== excludeClientId && client.deviceType === deviceType && client.authenticated && client.ws.readyState === WebSocket.OPEN) {
      client.ws.send(JSON.stringify(message));
    }
  });
}

function broadcastExceptType(excludeDeviceType, message, excludeClientId = null) {
  clients.forEach((client, clientId) => {
    if (clientId !== excludeClientId && client.deviceType !== excludeDeviceType && client.authenticated && client.ws.readyState === WebSocket.OPEN) {
      client.ws.send(JSON.stringify(message));
    }
  });
}

// ============ 디바이스 상태 ============

function getDeviceList() {
  const devices = [];
  clients.forEach((client) => {
    if (client.authenticated) {
      const info = getDeviceInfo(client.deviceId);
      devices.push({
        deviceId: client.deviceId,
        deviceType: client.deviceType,
        name: info.name,
        icon: info.icon,
        role: info.role,
        connectedAt: client.connectedAt.toISOString()
      });
    }
  });
  return devices;
}

function broadcastDeviceStatus() {
  const devices = getDeviceList();
  broadcast({ type: 'device_status', payload: { devices } });
  log(`Device status: ${devices.length} authenticated`);
}

// ============ 메시지 핸들러 ============

function handleMessage(clientId, data) {
  const client = clients.get(clientId);
  if (!client) return;

  const { type, to, broadcast: shouldBroadcast } = data;

  // ===== 인증 =====
  if (type === 'auth') {
    let { deviceId, deviceType } = data.payload || {};

    // deviceId 정규화 (문자열이면 숫자로)
    if (typeof deviceId === 'string') {
      const parsed = parseInt(deviceId, 10);
      deviceId = isNaN(parsed) ? null : parsed;
    }

    if (deviceId === null || deviceId === undefined || !deviceType) {
      sendTo(clientId, { type: 'auth_result', payload: { success: false, error: 'Missing deviceId or deviceType' } });
      return;
    }

    const authResult = authenticateDevice(deviceId, deviceType, client.ip);

    if (authResult.success) {
      client.deviceId = deviceId;
      client.deviceType = deviceType;
      client.authenticated = true;

      const info = getDeviceInfo(deviceId);
      log(`Authenticated: ${info.name} (${deviceId}/${deviceType}) from ${client.ip}`);

      sendTo(clientId, {
        type: 'auth_result',
        payload: {
          success: true,
          device: { deviceId, deviceType, name: info.name, icon: info.icon, role: info.role }
        }
      });
      broadcastDeviceStatus();
    } else {
      log(`Auth failed: ${deviceId} from ${client.ip} - ${authResult.error}`);
      sendTo(clientId, { type: 'auth_result', payload: { success: false, error: authResult.error } });
    }
    return;
  }

  // ===== 인증 필요 =====
  if (!client.authenticated) {
    sendTo(clientId, { type: 'error', payload: { error: 'Not authenticated' } });
    return;
  }

  // ===== Relay 내부 처리 (최소한만) =====

  if (type === 'get_devices' || type === 'getDevices') {
    sendTo(clientId, { type: 'device_list', payload: { devices: getDeviceList() } });
    return;
  }

  if (type === 'ping') {
    sendTo(clientId, { type: 'pong', payload: {} });
    return;
  }

  // ===== 순수 라우팅 =====

  // from 정보 주입
  const info = getDeviceInfo(client.deviceId);
  data.from = {
    deviceId: client.deviceId,
    deviceType: client.deviceType,
    name: info.name,
    icon: info.icon
  };

  // 1. to가 있으면 해당 대상으로 전달
  if (to) {
    let { deviceId, deviceType } = to;

    // deviceId 정규화
    if (typeof deviceId === 'string') {
      const parsed = parseInt(deviceId, 10);
      deviceId = isNaN(parsed) ? null : parsed;
    }

    if (deviceId === null) {
      sendTo(clientId, { type: 'error', payload: { error: 'Invalid deviceId in to' } });
      return;
    }

    const sent = sendToDevice(deviceId, deviceType, data);
    if (!sent) {
      const targetInfo = getDeviceInfo(deviceId);
      sendTo(clientId, { type: 'error', payload: { error: `Target offline: ${targetInfo.name} (${deviceId}/${deviceType || '*'})` } });
    }
    return;
  }

  // 2. broadcast 옵션 처리
  if (shouldBroadcast) {
    if (shouldBroadcast === 'all') {
      broadcast(data, clientId);
    } else if (shouldBroadcast === 'pylons') {
      broadcastToType('pylon', data, clientId);
    } else if (shouldBroadcast === 'clients') {
      broadcastExceptType('pylon', data, clientId);
    } else if (typeof shouldBroadcast === 'string') {
      broadcastToType(shouldBroadcast, data, clientId);
    }
    return;
  }

  // 3. 기본 라우팅 규칙
  if (client.deviceType === 'pylon') {
    broadcastExceptType('pylon', data, clientId);
  } else {
    broadcastToType('pylon', data, clientId);
  }
}

// ============ WebSocket 서버 ============

const wss = new WebSocket.Server({ port: PORT });

wss.on('connection', (ws, req) => {
  const clientId = `client-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const clientIp = getClientIp(req);

  clients.set(clientId, {
    ws,
    deviceId: null,
    deviceType: null,
    ip: clientIp,
    connectedAt: new Date(),
    authenticated: false
  });

  log(`Connected: ${clientId} from ${clientIp} (total: ${clients.size})`);

  ws.send(JSON.stringify({ type: 'connected', payload: { clientId, message: 'Estelle Relay v1' } }));

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      handleMessage(clientId, data);
    } catch (err) {
      log(`Invalid message from ${clientId}: ${err.message}`);
      sendTo(clientId, { type: 'error', payload: { error: 'Invalid JSON' } });
    }
  });

  ws.on('close', () => {
    const client = clients.get(clientId);
    const deviceId = client?.deviceId;

    clients.delete(clientId);

    if (deviceId !== null) {
      const info = getDeviceInfo(deviceId);
      log(`Disconnected: ${info.name} (${deviceId}) (total: ${clients.size})`);
    } else {
      log(`Disconnected: ${clientId} (total: ${clients.size})`);
    }

    if (client?.authenticated) {
      broadcastDeviceStatus();
    }
  });

  ws.on('error', (err) => {
    log(`Error from ${clientId}: ${err.message}`);
  });
});

wss.on('listening', () => {
  log(`[Estelle Relay v1] Started on port ${PORT}`);
  log(`Registered devices: ${Object.entries(DEVICES).map(([id, d]) => `${d.name}(${id})`).join(', ')}`);
});

wss.on('error', (err) => {
  log(`Server error: ${err.message}`);
});

process.on('SIGINT', () => {
  log('Shutting down...');
  wss.close(() => {
    log('Server closed');
    process.exit(0);
  });
});
