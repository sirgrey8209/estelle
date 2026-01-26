/**
 * Estelle Relay - v1 (Pure Router)
 * 순수 중계기: 인증 + 라우팅만 담당
 * 메시지 내용은 해석하지 않음
 */

require('dotenv').config();
const WebSocket = require('ws');
const { execSync } = require('child_process');
const https = require('https');
const path = require('path');

const PORT = process.env.PORT || 8080;
const REPO_DIR = path.resolve(__dirname, '..', '..');
const DEPLOY_JSON_URL = 'https://github.com/sirgrey8209/estelle/releases/download/deploy/deploy.json';

// ============ 디바이스 정의 ============
const DEVICES = {
  1: { name: 'Device 1', icon: '🏢', role: 'office', allowedIps: ['*'] },
  2: { name: 'Device 2', icon: '🏠', role: 'home', allowedIps: ['*'] },
};

// 동적 디바이스 ID 범위 (100 이상은 동적 허용)
const DYNAMIC_DEVICE_ID_START = 100;

// ============ 상태 저장소 ============
const clients = new Map();  // clientId -> ClientInfo
let nextClientId = DYNAMIC_DEVICE_ID_START;  // 앱 클라이언트용 ID 카운터

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
  if (DEVICES[deviceId]) {
    return DEVICES[deviceId];
  }
  // 동적 디바이스 (100 이상)
  if (deviceId >= DYNAMIC_DEVICE_ID_START) {
    return { name: `Client ${deviceId}`, icon: '📱', role: 'client' };
  }
  return { name: `Device ${deviceId}`, icon: '💻', role: 'unknown' };
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

// ============ 자동 업데이트 ============

function fetchDeployJson() {
  return new Promise((resolve) => {
    const url = `${DEPLOY_JSON_URL}?t=${Date.now()}`;
    https.get(url, { headers: { 'User-Agent': 'Estelle-Relay' } }, (res) => {
      if (res.statusCode === 302 || res.statusCode === 301) {
        https.get(res.headers.location, (res2) => {
          let data = '';
          res2.on('data', chunk => data += chunk);
          res2.on('end', () => { try { resolve(JSON.parse(data)); } catch { resolve(null); } });
        }).on('error', () => resolve(null));
        return;
      }
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => { try { resolve(JSON.parse(data)); } catch { resolve(null); } });
    }).on('error', () => resolve(null));
  });
}

function getLocalCommit() {
  try {
    return execSync('git rev-parse --short HEAD', { cwd: REPO_DIR, encoding: 'utf-8' }).trim();
  } catch {
    return null;
  }
}

async function checkAndUpdate() {
  log('Checking for updates...');
  try {
    const localCommit = getLocalCommit();
    if (!localCommit) {
      log('Could not get local commit');
      return { success: false, message: 'Could not get local commit' };
    }
    log(`Local commit: ${localCommit}`);

    const deployInfo = await fetchDeployJson();
    if (!deployInfo) {
      log('No deploy info found');
      return { success: false, message: 'No deploy info found' };
    }
    log(`Deploy commit: ${deployInfo.commit}`);

    if (localCommit === deployInfo.commit) {
      log('Already up to date');
      return { success: true, message: 'Already up to date', updated: false };
    }

    log('Update available, pulling...');
    execSync('git fetch origin', { cwd: REPO_DIR, encoding: 'utf-8' });
    execSync(`git checkout ${deployInfo.commit}`, { cwd: REPO_DIR, encoding: 'utf-8' });

    const relayDir = path.join(REPO_DIR, 'estelle-relay');
    log('Running npm install...');
    execSync('npm install', { cwd: relayDir, encoding: 'utf-8' });

    log(`Updated to ${deployInfo.commit}`);
    return { success: true, message: `Updated to ${deployInfo.commit}`, updated: true };
  } catch (err) {
    log(`Update failed: ${err.message}`);
    return { success: false, message: err.message };
  }
}

function handleRelayUpdate(clientId, data) {
  const client = clients.get(clientId);
  // Pylon만 업데이트 요청 가능
  if (!client || client.deviceType !== 'pylon') {
    sendTo(clientId, { type: 'relay_update_result', payload: { success: false, error: 'Only pylons can trigger relay update' } });
    return;
  }

  log(`Relay update requested by: ${data.from?.name || client.deviceId}`);

  checkAndUpdate().then(result => {
    sendTo(clientId, { type: 'relay_update_result', payload: result });

    if (result.updated) {
      log('Restarting Relay...');
      broadcast({ type: 'relay_restarting', payload: { message: 'Relay is restarting for update' } });
      setTimeout(() => process.exit(0), 1000);
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

    if (!deviceType) {
      sendTo(clientId, { type: 'auth_result', payload: { success: false, error: 'Missing deviceType' } });
      return;
    }

    // pylon은 deviceId 필수, app은 자동 발급
    if (deviceType === 'pylon') {
      // deviceId 정규화 (문자열이면 숫자로)
      if (typeof deviceId === 'string') {
        const parsed = parseInt(deviceId, 10);
        deviceId = isNaN(parsed) ? null : parsed;
      }

      if (deviceId === null || deviceId === undefined) {
        sendTo(clientId, { type: 'auth_result', payload: { success: false, error: 'Missing deviceId for pylon' } });
        return;
      }

      const authResult = authenticateDevice(deviceId, deviceType, client.ip);
      if (!authResult.success) {
        log(`Auth failed: ${deviceId} from ${client.ip} - ${authResult.error}`);
        sendTo(clientId, { type: 'auth_result', payload: { success: false, error: authResult.error } });
        return;
      }
    } else {
      // app 클라이언트: deviceId 자동 발급
      deviceId = nextClientId++;
      log(`Assigned deviceId ${deviceId} to ${deviceType} client`);
    }

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

  // Relay 업데이트 요청 (Pylon만 가능)
  if (type === 'relay_update') {
    handleRelayUpdate(clientId, data);
    return;
  }

  // Relay 버전 확인
  if (type === 'relay_version') {
    const commit = getLocalCommit();
    sendTo(clientId, { type: 'relay_version_result', payload: { commit } });
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
    // 배열 지원: to: [105, 106] 또는 to: [{ deviceId: 105 }, { deviceId: 106 }]
    const targets = Array.isArray(to) ? to : [to];

    for (const target of targets) {
      let deviceId, deviceType;

      // 숫자만 오면 deviceId로 처리
      if (typeof target === 'number') {
        deviceId = target;
        deviceType = null;
      } else if (typeof target === 'object') {
        deviceId = target.deviceId;
        deviceType = target.deviceType;
      } else {
        continue;
      }

      // deviceId 정규화
      if (typeof deviceId === 'string') {
        const parsed = parseInt(deviceId, 10);
        deviceId = isNaN(parsed) ? null : parsed;
      }

      if (deviceId === null) {
        continue;
      }

      sendToDevice(deviceId, deviceType, data);
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
    const deviceType = client?.deviceType;

    clients.delete(clientId);

    if (deviceId !== null) {
      const info = getDeviceInfo(deviceId);
      log(`Disconnected: ${info.name} (${deviceId}) (total: ${clients.size})`);
    } else {
      log(`Disconnected: ${clientId} (total: ${clients.size})`);
    }

    if (client?.authenticated) {
      broadcastDeviceStatus();

      // 클라이언트(비-pylon) 연결 해제 시 pylon에 알림
      if (deviceType !== 'pylon' && deviceId !== null) {
        broadcastToType('pylon', {
          type: 'client_disconnect',
          payload: { deviceId, deviceType }
        });

        // 모든 앱 클라이언트가 연결 해제되면 ID 카운터 리셋
        const hasAppClients = Array.from(clients.values()).some(
          c => c.authenticated && c.deviceType !== 'pylon'
        );
        if (!hasAppClients) {
          nextClientId = DYNAMIC_DEVICE_ID_START;
          log(`All app clients disconnected, reset nextClientId to ${nextClientId}`);
        }
      }
    }
  });

  ws.on('error', (err) => {
    log(`Error from ${clientId}: ${err.message}`);
  });
});

wss.on('listening', async () => {
  log(`[Estelle Relay v1] Started on port ${PORT}`);
  log(`Registered devices: ${Object.entries(DEVICES).map(([id, d]) => `${d.name}(${id})`).join(', ')}`);

  // 시작 시 자동 업데이트 체크
  const result = await checkAndUpdate();
  if (result.updated) {
    log('Restarting after update...');
    setTimeout(() => process.exit(0), 1000);
  }
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
