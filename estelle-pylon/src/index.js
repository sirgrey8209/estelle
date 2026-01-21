/**
 * Estelle Pylon - v1
 * Claude SDK 실행, 데스크 관리, Relay 통신
 */

import 'dotenv/config';
import { execSync } from 'child_process';
import WebSocket from 'ws';
import path from 'path';
import https from 'https';
import fs from 'fs';
import { fileURLToPath } from 'url';

import deskStore from './deskStore.js';
import ClaudeManager from './claudeManager.js';
import LocalServer from './localServer.js';
import PidManager from './pidManager.js';
import logger from './logger.js';
import packetLogger from './packetLogger.js';
import FileSimulator from './fileSimulator.js';
import messageStore from './messageStore.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ============ 설정 ============
const RELAY_URL = process.env.RELAY_URL || 'ws://localhost:8080';
const LOCAL_PORT = parseInt(process.env.LOCAL_PORT) || 9000;
const DEVICE_ID = parseInt(process.env.DEVICE_ID) || 1;
const RECONNECT_INTERVAL = 5000;
const FILE_SIMULATOR_ENABLED = process.env.FILE_SIMULATOR === 'true';
const REPO_DIR = path.resolve(__dirname, '..', '..');
const DEPLOY_JSON_URL = 'https://github.com/sirgrey8209/estelle/releases/download/deploy/deploy.json';

class Pylon {
  constructor() {
    this.deviceId = DEVICE_ID;
    this.ws = null;
    this.authenticated = false;
    this.deviceInfo = null;
    this.reconnectTimer = null;
    this.localServer = null;
    this.claudeManager = null;
    this.fileSimulator = null;
  }

  log(message) {
    logger.log(`[${new Date().toISOString()}] ${message}`);
  }

  async start() {
    PidManager.initialize();

    this.log(`[Estelle Pylon v1] Starting...`);
    this.log(`Device ID: ${this.deviceId}`);
    this.log(`Relay URL: ${RELAY_URL}`);
    this.log(`Local Port: ${LOCAL_PORT}`);

    await this.checkAndUpdate();

    deskStore.initialize();

    this.claudeManager = new ClaudeManager((deskId, event) => {
      this.sendClaudeEvent(deskId, event);
    });

    this.localServer = new LocalServer(LOCAL_PORT);
    this.localServer.setRelayStatusCallback(() => this.authenticated);
    this.localServer.onConnect((ws) => this.onDesktopConnect(ws));
    this.setupLocalServer();
    this.localServer.start();

    this.fileSimulator = new FileSimulator(path.join(__dirname, '..', 'debug'), {
      enabled: FILE_SIMULATOR_ENABLED,
      pollInterval: 500,
      log: (msg) => this.log(msg),
      onMessage: (msg) => {
        packetLogger.logRecv('file', msg);
        this.handleMessage(msg);
      }
    });
    this.fileSimulator.initialize();

    this.connectToRelay();

    process.on('SIGINT', () => {
      this.log('Shutting down...');
      this.claudeManager?.cleanup();
      this.ws?.close();
      this.localServer?.stop();
      this.fileSimulator?.stop();
      process.exit(0);
    });
  }

  // ============ Local Server ============

  setupLocalServer() {
    this.localServer.onMessage((data, ws) => {
      if (data.type !== 'ping') {
        packetLogger.logRecv('desktop', data);
      }

      if (data.type === 'ping') {
        ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
        return;
      }

      if (data.type === 'get_status') {
        ws.send(JSON.stringify({
          type: 'status',
          deviceId: this.deviceId,
          deviceInfo: this.deviceInfo,
          authenticated: this.authenticated,
          desks: deskStore.getAllDesks()
        }));
        return;
      }

      if (data.type === 'run_deploy') {
        this.handleDeploy(data, ws);
        return;
      }

      if (data.type === 'get_git_commit') {
        try {
          const commit = execSync('git rev-parse --short HEAD', { cwd: REPO_DIR, encoding: 'utf-8' }).trim();
          ws.send(JSON.stringify({ type: 'git_commit', commit }));
        } catch (err) {
          ws.send(JSON.stringify({ type: 'git_commit', commit: null, error: err.message }));
        }
        return;
      }

      if (data.to) {
        const targetDeviceId = data.to.deviceId;
        if (targetDeviceId === this.deviceId) {
          this.handleMessage(data);
        } else {
          this.send(data);
        }
        return;
      }

      this.handleMessage(data);
    });
  }

  // ============ Relay 연결 ============

  connectToRelay() {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) return;

    this.log(`Connecting to Relay: ${RELAY_URL}`);

    try {
      this.ws = new WebSocket(RELAY_URL);
    } catch (err) {
      this.log(`Connection error: ${err.message}`);
      this.scheduleReconnect();
      return;
    }

    this.ws.on('open', () => {
      this.log('Connected to Relay');
      this.authenticate();
      this.localServer?.broadcast({ type: 'relay_status', connected: true });
    });

    this.ws.on('message', (data) => {
      try {
        const message = JSON.parse(data.toString());
        packetLogger.logRecv('relay', message);
        this.handleMessage(message);
      } catch (err) {
        this.log(`Invalid message: ${err.message}`);
      }
    });

    this.ws.on('close', () => {
      this.log('Disconnected from Relay');
      this.authenticated = false;
      this.deviceInfo = null;
      this.localServer?.broadcast({ type: 'relay_status', connected: false });
      this.scheduleReconnect();
    });

    this.ws.on('error', (err) => {
      this.log(`WebSocket error: ${err.message}`);
    });
  }

  scheduleReconnect() {
    if (this.reconnectTimer) return;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connectToRelay();
    }, RECONNECT_INTERVAL);
  }

  send(message) {
    packetLogger.logSend('relay', message);

    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    }
  }

  authenticate() {
    this.send({
      type: 'auth',
      payload: {
        deviceId: this.deviceId,
        deviceType: 'pylon'
      }
    });
  }

  // ============ 메시지 처리 ============

  handleMessage(message) {
    const { type, payload, from } = message;

    if (type === 'connected') {
      this.log(`Connected to Relay: ${payload?.message || ''}`);
      return;
    }

    if (type === 'auth_result') {
      if (payload?.success) {
        this.authenticated = true;
        this.deviceInfo = payload.device;
        this.log(`Authenticated as ${this.deviceInfo?.name || this.deviceId}`);
        this.broadcastDeskList();
      } else {
        this.log(`Auth failed: ${payload?.error}`);
      }
      return;
    }

    if (type === 'device_status') {
      this.localServer?.broadcast({ type: 'device_status', devices: payload?.devices });
      return;
    }

    if (type === 'error') {
      this.log(`Error from Relay: ${payload?.error}`);
      return;
    }

    // ===== 데스크 관련 =====

    if (type === 'desk_list') {
      // from 정보가 있으면 요청자에게 직접 응답, 없으면 브로드캐스트
      if (from?.deviceId) {
        this.sendDeskListTo(from);
      } else {
        this.broadcastDeskList();
      }
      return;
    }

    if (type === 'desk_switch') {
      const { deskId } = payload || {};
      if (deskId && deskStore.setActiveDesk(deskId)) {
        this.broadcastDeskList();
      }
      return;
    }

    if (type === 'desk_create') {
      const { name, workingDir } = payload || {};
      if (name) {
        deskStore.createDesk(name, workingDir);
        this.broadcastDeskList();
      }
      return;
    }

    if (type === 'desk_delete') {
      const { deskId } = payload || {};
      if (deskId && deskStore.deleteDesk(deskId)) {
        this.claudeManager.stop(deskId);
        this.broadcastDeskList();
      }
      return;
    }

    if (type === 'desk_rename') {
      const { deskId, newName } = payload || {};
      if (deskId && newName && deskStore.renameDesk(deskId, newName)) {
        this.broadcastDeskList();
      }
      return;
    }

    // ===== Claude 관련 =====

    if (type === 'claude_send') {
      const { deskId, message: userMessage } = payload || {};
      if (deskId && userMessage) {
        // 사용자 메시지 저장
        messageStore.addUserMessage(deskId, userMessage);
        this.claudeManager.sendMessage(deskId, userMessage);
      }
      return;
    }

    if (type === 'claude_permission') {
      const { deskId, toolUseId, decision } = payload || {};
      if (deskId && toolUseId && decision) {
        this.claudeManager.respondPermission(deskId, toolUseId, decision);
      }
      return;
    }

    if (type === 'claude_answer') {
      const { deskId, toolUseId, answer } = payload || {};
      if (deskId && toolUseId) {
        this.claudeManager.respondQuestion(deskId, toolUseId, answer);
      }
      return;
    }

    if (type === 'claude_control') {
      const { deskId, action } = payload || {};
      if (deskId && action) {
        this.handleClaudeControl(deskId, action);
      }
      return;
    }

    if (type === 'claude_set_permission_mode') {
      const { mode } = payload || {};
      if (mode) {
        deskStore.setPermissionMode(mode);
      }
      return;
    }

    // ===== 배포/업데이트 =====

    if (type === 'update') {
      this.handleUpdate(message);
      return;
    }

    if (type === 'deploy_request') {
      this.handleRemoteDeploy(message);
      return;
    }

    this.localServer?.broadcast({ type: 'from_relay', data: message });
  }

  handleClaudeControl(deskId, action) {
    switch (action) {
      case 'stop':
        this.claudeManager.stop(deskId);
        break;
      case 'new_session':
      case 'clear':
        this.claudeManager.newSession(deskId);
        messageStore.clear(deskId);
        this.broadcastDeskList();
        break;
      case 'resume':
        // 세션 재개 - 빈 메시지로 컨텍스트 복구
        this.claudeManager.resumeSession(deskId);
        this.broadcastDeskList();
        break;
      case 'compact':
        this.log(`Compact not implemented yet`);
        break;
    }
  }

  // ============ 데스크 정보 전송 ============

  onDesktopConnect(ws) {
    const desks = deskStore.getAllDesks();

    // 각 데스크에 세션 상태 추가
    const desksWithSessionInfo = desks.map(desk => ({
      ...desk,
      hasActiveSession: this.claudeManager.hasActiveSession(desk.deskId),
      canResume: !!desk.claudeSessionId
    }));

    // 데스크 목록 전송
    const deskListMsg = {
      type: 'desk_list_result',
      payload: {
        deviceId: this.deviceId,
        deviceInfo: this.deviceInfo,
        desks: desksWithSessionInfo
      }
    };
    ws.send(JSON.stringify(deskListMsg));
    packetLogger.logSend('desktop', deskListMsg);

    // 각 데스크의 메시지 히스토리 전송
    for (const desk of desks) {
      const messages = messageStore.load(desk.deskId);
      if (messages.length > 0) {
        const historyMsg = {
          type: 'message_history',
          payload: {
            deviceId: this.deviceId,
            deskId: desk.deskId,
            messages
          }
        };
        ws.send(JSON.stringify(historyMsg));
        packetLogger.logSend('desktop', historyMsg);
      }

      // pending 이벤트 전송 (질문/권한 요청)
      const pendingEvent = this.claudeManager.getPendingEvent(desk.deskId);
      if (pendingEvent) {
        const eventMsg = {
          type: 'claude_event',
          payload: {
            deskId: desk.deskId,
            event: pendingEvent
          }
        };
        ws.send(JSON.stringify(eventMsg));
        packetLogger.logSend('desktop', eventMsg);
      }
    }
  }

  // 특정 클라이언트에게 데스크 목록 전송
  sendDeskListTo(target) {
    const desks = deskStore.getAllDesks();

    const desksWithSessionInfo = desks.map(desk => ({
      ...desk,
      hasActiveSession: this.claudeManager.hasActiveSession(desk.deskId),
      canResume: !!desk.claudeSessionId
    }));

    const payload = {
      deviceId: this.deviceId,
      deviceInfo: this.deviceInfo,
      desks: desksWithSessionInfo
    };

    this.send({
      type: 'desk_list_result',
      payload,
      to: { deviceId: target.deviceId, deviceType: target.deviceType }
    });
  }

  broadcastDeskList() {
    const desks = deskStore.getAllDesks();

    // 각 데스크에 세션 상태 추가
    const desksWithSessionInfo = desks.map(desk => ({
      ...desk,
      hasActiveSession: this.claudeManager.hasActiveSession(desk.deskId),
      canResume: !!desk.claudeSessionId
    }));

    const payload = {
      deviceId: this.deviceId,
      deviceInfo: this.deviceInfo,
      desks: desksWithSessionInfo
    };

    this.send({
      type: 'desk_list_result',
      payload,
      broadcast: 'clients'
    });

    this.localServer?.broadcast({
      type: 'desk_list_result',
      payload
    });
  }

  // ============ Claude 이벤트 전송 ============

  sendClaudeEvent(deskId, event) {
    // 이벤트 타입별 메시지 저장
    this.saveEventToHistory(deskId, event);

    const message = {
      type: 'claude_event',
      payload: { deskId, event }
    };

    this.send({ ...message, broadcast: 'clients' });
    this.localServer?.broadcast(message);

    if (event.type === 'state') {
      const desk = deskStore.getDesk(deskId);
      if (desk) {
        this.send({
          type: 'desk_status',
          payload: {
            deviceId: this.deviceId,
            deskId: desk.deskId,
            status: desk.status,
            isActive: desk.isActive
          },
          broadcast: 'clients'
        });
      }
    }
  }

  /**
   * 이벤트를 메시지 히스토리에 저장
   */
  saveEventToHistory(deskId, event) {
    switch (event.type) {
      case 'textComplete':
        messageStore.addAssistantText(deskId, event.text);
        break;

      case 'toolInfo':
        messageStore.addToolStart(deskId, event.toolName, event.input);
        break;

      case 'toolComplete':
        messageStore.updateToolComplete(
          deskId,
          event.toolName,
          event.success,
          event.result,
          event.error
        );
        break;

      case 'error':
        messageStore.addError(deskId, event.error);
        break;

      case 'result':
        messageStore.addResult(deskId, {
          duration_ms: event.duration_ms,
          total_cost_usd: event.total_cost_usd,
          num_turns: event.num_turns,
          usage: event.usage
        });
        break;
    }
  }

  // ============ 업데이트/배포 ============

  async checkAndUpdate() {
    this.log('Checking for updates...');
    try {
      const localCommit = execSync('git rev-parse --short HEAD', { cwd: REPO_DIR, encoding: 'utf-8' }).trim();
      this.log(`Local commit: ${localCommit}`);

      const deployInfo = await this.fetchDeployJson();
      if (!deployInfo) {
        this.log('No deploy info found, skipping update');
        return;
      }

      this.log(`Deployed commit: ${deployInfo.commit}`);

      if (localCommit !== deployInfo.commit) {
        this.log('Update available, syncing...');
        execSync('git fetch origin', { cwd: REPO_DIR, encoding: 'utf-8' });
        execSync(`git checkout ${deployInfo.commit}`, { cwd: REPO_DIR, encoding: 'utf-8' });

        const pylonDir = path.join(REPO_DIR, 'estelle-pylon');
        this.log('Running npm install...');
        execSync('npm install', { cwd: pylonDir, encoding: 'utf-8' });

        this.log(`Updated to ${deployInfo.commit}, restarting...`);
        setTimeout(() => process.exit(0), 1000);
        return;
      }

      this.log('Already up to date');
    } catch (err) {
      this.log(`Update check failed: ${err.message}`);
    }
  }

  fetchDeployJson() {
    return new Promise((resolve) => {
      const url = `${DEPLOY_JSON_URL}?t=${Date.now()}`;
      https.get(url, { headers: { 'User-Agent': 'Estelle-Pylon' } }, (res) => {
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

  handleUpdate(data) {
    this.log(`Update requested by: ${data.from?.name || data.from?.deviceId}`);
    try {
      this.log('Running git fetch...');
      execSync('git fetch origin', { cwd: REPO_DIR, encoding: 'utf-8' });

      try {
        execSync('git diff HEAD origin/master --quiet', { cwd: REPO_DIR, encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
        this.send({ type: 'update_result', payload: { success: true, message: 'Already up to date' } });
        this.log('Already up to date');
      } catch (err) {
        if (err.status === 1) {
          this.log('Changes detected, running git pull...');
          execSync('git pull origin master', { cwd: REPO_DIR, encoding: 'utf-8' });

          const pylonDir = path.join(REPO_DIR, 'estelle-pylon');
          try {
            execSync('git diff HEAD~1 --name-only | findstr package-lock.json', { cwd: REPO_DIR, encoding: 'utf-8' });
            this.log('package-lock.json changed, running npm install...');
            execSync('npm install', { cwd: pylonDir, encoding: 'utf-8' });
          } catch {}

          this.send({ type: 'update_result', payload: { success: true, message: 'Updated successfully. Restarting...' } });
          this.log('Restarting Pylon...');
          setTimeout(() => process.exit(0), 1000);
        } else {
          throw err;
        }
      }
    } catch (err) {
      this.log(`Update failed: ${err.message}`);
      this.send({ type: 'update_result', payload: { success: false, message: `Update failed: ${err.message}` } });
    }
  }

  handleRemoteDeploy(data) {
    this.log(`Remote deploy requested by: ${data.from?.name || data.from?.deviceId}`);
    try {
      const scriptPath = path.join(REPO_DIR, 'scripts', 'deploy.ps1');
      const result = execSync(`powershell -ExecutionPolicy Bypass -File "${scriptPath}"`, {
        cwd: REPO_DIR, encoding: 'utf-8', timeout: 300000
      });
      this.log(result);
      this.send({ type: 'deploy_result', payload: { success: true, message: 'Deploy completed' } });
    } catch (err) {
      this.log(`Remote deploy failed: ${err.message}`);
      this.send({ type: 'deploy_result', payload: { success: false, message: err.message } });
    }
  }

  handleDeploy(data, ws) {
    this.log(`Deploy requested, force: ${data.force}`);
    try {
      const scriptPath = path.join(REPO_DIR, 'scripts', 'deploy.ps1');
      const args = data.force ? '-Force' : '';
      const result = execSync(`powershell -ExecutionPolicy Bypass -File "${scriptPath}" ${args}`, {
        cwd: REPO_DIR, encoding: 'utf-8', timeout: 300000
      });
      this.log(result);
      ws.send(JSON.stringify({ type: 'deploy_result', success: true, message: 'Deploy completed' }));
    } catch (err) {
      this.log(`Deploy failed: ${err.message}`);
      ws.send(JSON.stringify({ type: 'deploy_result', success: false, message: err.message }));
    }
  }
}

// 직접 실행
const pylon = new Pylon();
pylon.start().catch(err => {
  logger.error(`Fatal error: ${err}`);
  process.exit(1);
});

export default Pylon;
