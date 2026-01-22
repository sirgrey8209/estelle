/**
 * Estelle Pylon - v1
 * Claude SDK 실행, 데스크 관리, Relay 통신
 */

import 'dotenv/config';
import { execSync, spawn } from 'child_process';
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
    // 데스크별 시청자 추적: Map<deskId, Set<clientDeviceId>>
    this.deskViewers = new Map();
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
      messageStore.saveAll();
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

    if (type === 'client_disconnect') {
      const clientId = payload?.deviceId;
      if (clientId) {
        this.unregisterDeskViewer(clientId);
      }
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
        const newDesk = deskStore.createDesk(name, workingDir);
        this.broadcastDeskList();
        // 생성 요청자에게 새 데스크 정보 전송
        this.sendToClient(clientId, {
          type: 'desk_created',
          payload: {
            deviceId: this.deviceId,
            desk: newDesk,
          },
        });
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

    if (type === 'desk_sync') {
      const { deskId } = payload || {};
      if (deskId) {
        this.sendDeskSync(deskId, from);
      }
      return;
    }

    if (type === 'desk_select') {
      const { deskId } = payload || {};
      const clientId = from?.deviceId;
      if (deskId && clientId) {
        this.registerDeskViewer(clientId, deskId);
      }
      return;
    }

    // 히스토리 페이징 요청
    if (type === 'history_request') {
      const { deskId, limit = 50, offset = 0 } = payload || {};
      if (deskId) {
        const totalCount = messageStore.getCount(deskId);
        const messages = messageStore.load(deskId, { limit, offset });
        const hasMore = offset + messages.length < totalCount;

        this.send({
          type: 'history_result',
          to: from?.deviceId,
          payload: {
            deviceId: this.deviceId,
            deskId,
            messages,
            offset,
            totalCount,
            hasMore
          }
        });
      }
      return;
    }

    // ===== Claude 관련 =====

    if (type === 'claude_send') {
      const { deskId, message: userMessage } = payload || {};
      if (deskId && userMessage) {
        // 사용자 메시지 저장
        messageStore.addUserMessage(deskId, userMessage);

        // 사용자 메시지 브로드캐스트 (다른 클라이언트들에게 알림)
        const userMessageEvent = {
          type: 'claude_event',
          payload: {
            deskId,
            event: {
              type: 'userMessage',
              content: userMessage,
              timestamp: Date.now()
            }
          }
        };
        this.send({ ...userMessageEvent, broadcast: 'clients' });
        this.localServer?.broadcast(userMessageEvent);

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

    // 2단계 배포 시스템
    if (type === 'deploy_prepare') {
      this.handleDeployPrepare(message);
      return;
    }

    if (type === 'deploy_go') {
      this.handleDeployGo(message);
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

  // ============ 데스크 시청자 관리 ============

  /**
   * 클라이언트를 특정 데스크의 시청자로 등록
   * 한 클라이언트는 한 데스크만 시청 가능
   */
  registerDeskViewer(clientId, deskId) {
    // 기존 시청 데스크에서 제거
    for (const [existingDeskId, viewers] of this.deskViewers) {
      if (viewers.has(clientId)) {
        viewers.delete(clientId);
        if (viewers.size === 0) {
          this.deskViewers.delete(existingDeskId);
          // 시청자가 없으면 메시지 캐시 해제
          messageStore.unloadCache(existingDeskId);
          this.log(`Unloaded message cache for desk ${existingDeskId} (no viewers)`);
        }
        break;
      }
    }

    // 새 데스크에 등록
    if (!this.deskViewers.has(deskId)) {
      this.deskViewers.set(deskId, new Set());
    }
    this.deskViewers.get(deskId).add(clientId);
    this.log(`Client ${clientId} now viewing desk ${deskId}`);
  }

  /**
   * 클라이언트 연결 해제 시 모든 시청 정보 제거
   */
  unregisterDeskViewer(clientId) {
    for (const [deskId, viewers] of this.deskViewers) {
      if (viewers.has(clientId)) {
        viewers.delete(clientId);
        if (viewers.size === 0) {
          this.deskViewers.delete(deskId);
          // 시청자가 없으면 메시지 캐시 해제
          messageStore.unloadCache(deskId);
          this.log(`Unloaded message cache for desk ${deskId} (no viewers)`);
        }
        this.log(`Client ${clientId} removed from desk ${deskId} viewers`);
        break;
      }
    }
  }

  /**
   * 특정 데스크를 시청 중인 클라이언트 목록 반환
   */
  getDeskViewers(deskId) {
    return this.deskViewers.get(deskId) || new Set();
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

  /**
   * 특정 데스크의 메시지 히스토리 전송 (sync 요청 응답)
   */
  sendDeskSync(deskId, target) {
    const desk = deskStore.getDesk(deskId);
    const totalCount = messageStore.getCount(deskId);

    // 메시지는 history_request로 페이징해서 받도록 함
    // 여기서는 상태 정보만 전송
    const syncPayload = {
      deviceId: this.deviceId,
      deskId,
      messages: [],  // 빈 배열 - 앱에서 history_request로 받아야 함
      totalCount,    // 전체 메시지 수
      status: desk?.status || 'idle',
      hasActiveSession: this.claudeManager.hasActiveSession(deskId),
      canResume: !!desk?.claudeSessionId
    };

    // pending 이벤트도 포함
    const pendingEvent = this.claudeManager.getPendingEvent(deskId);
    if (pendingEvent) {
      syncPayload.pendingEvent = pendingEvent;
    }

    if (target?.deviceId) {
      // 요청자에게만 응답
      this.send({
        type: 'desk_sync_result',
        payload: syncPayload,
        to: { deviceId: target.deviceId, deviceType: target.deviceType }
      });
    } else {
      // 브로드캐스트
      this.send({
        type: 'desk_sync_result',
        payload: syncPayload,
        broadcast: 'clients'
      });
    }

    this.localServer?.broadcast({
      type: 'desk_sync_result',
      payload: syncPayload
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

    // 해당 데스크를 시청 중인 클라이언트에게만 전송
    const viewers = this.getDeskViewers(deskId);
    if (viewers.size > 0) {
      // 배열로 한 번에 전송
      this.send({
        ...message,
        to: Array.from(viewers)
      });
    }

    // 로컬 서버는 그대로 브로드캐스트 (보통 1개 연결)
    this.localServer?.broadcast(message);

    // 상태 변경은 모든 클라이언트에게 브로드캐스트 (사이드바 표시용)
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

  // ============ 2단계 배포 시스템 ============

  /**
   * 1단계: 배포 준비
   * - git pull로 최신 코드 받기
   * - relayDeploy가 true면 fly deploy 실행
   * - 완료 후 deploy_ready 전송
   */
  async handleDeployPrepare(message) {
    const { relayDeploy } = message.payload || {};
    const from = message.from;

    this.log(`Deploy prepare requested. relayDeploy: ${relayDeploy}`);

    try {
      // 1. git pull
      this.log('Running git fetch && git pull...');
      execSync('git fetch origin', { cwd: REPO_DIR, encoding: 'utf-8' });
      execSync('git pull origin master', { cwd: REPO_DIR, encoding: 'utf-8' });
      this.log('Git pull completed');

      // 2. Relay 배포 (지정된 Pylon만)
      if (relayDeploy) {
        this.log('Deploying Relay to Fly.io...');
        try {
          const relayDir = path.join(REPO_DIR, 'estelle-relay');
          execSync('fly deploy', { cwd: relayDir, encoding: 'utf-8', timeout: 300000 });
          this.log('Relay deploy completed');
        } catch (flyErr) {
          this.log(`Relay deploy failed: ${flyErr.message}`);
          // Relay 배포 실패해도 계속 진행 (Pylon은 업데이트 가능)
        }
      }

      // 3. APK 빌드 (Relay 배포 담당 Pylon만)
      if (relayDeploy) {
        this.log('Building APK...');
        try {
          const appDir = path.join(REPO_DIR, 'estelle-app');
          execSync('C:\\flutter\\bin\\flutter.bat build apk --release', {
            cwd: appDir, encoding: 'utf-8', timeout: 300000
          });
          this.log('APK build completed');

          // GitHub Release에 업로드
          execSync('gh release upload deploy build/app/outputs/flutter-apk/app-release.apk --clobber', {
            cwd: appDir, encoding: 'utf-8'
          });
          this.log('APK uploaded to GitHub Release');
        } catch (apkErr) {
          this.log(`APK build/upload failed: ${apkErr.message}`);
        }
      }

      // 4. 준비 완료 응답
      this.send({
        type: 'deploy_ready',
        payload: {
          deviceId: this.deviceId,
          success: true,
          relayDeployed: relayDeploy || false
        },
        broadcast: 'all'
      });

      this.log('Deploy prepare completed, ready for deploy_go');

    } catch (err) {
      this.log(`Deploy prepare failed: ${err.message}`);
      this.send({
        type: 'deploy_ready',
        payload: {
          deviceId: this.deviceId,
          success: false,
          error: err.message
        },
        broadcast: 'all'
      });
    }
  }

  /**
   * 2단계: 배포 실행
   * - 자가패치 배치파일 실행 후 종료
   * - pm2가 자동으로 재시작
   */
  handleDeployGo(message) {
    this.log('Deploy go received, starting self-patch...');

    // 연결 종료 예고
    this.send({
      type: 'deploy_restarting',
      payload: { deviceId: this.deviceId },
      broadcast: 'all'
    });

    // 배치파일 경로
    const batchPath = path.join(REPO_DIR, 'estelle-pylon', 'self-patch.bat');

    // 배치파일 생성 (동적으로)
    const batchContent = `@echo off
timeout /t 2 /nobreak > nul
cd /d "${path.join(REPO_DIR, 'estelle-pylon')}"
call npm install
pm2 restart pylon
`;
    fs.writeFileSync(batchPath, batchContent, 'utf-8');
    this.log(`Created self-patch.bat at ${batchPath}`);

    // 배치파일을 detached로 실행하고 프로세스 종료
    const child = spawn('cmd.exe', ['/c', batchPath], {
      detached: true,
      stdio: 'ignore',
      windowsHide: true
    });
    child.unref();

    this.log('Self-patch started, exiting...');

    // 잠시 후 종료 (메시지 전송 완료 대기)
    setTimeout(() => {
      process.exit(0);
    }, 500);
  }
}

// 직접 실행
const pylon = new Pylon();
pylon.start().catch(err => {
  logger.error(`Fatal error: ${err}`);
  process.exit(1);
});

export default Pylon;
