/**
 * Estelle Pylon - v1
 * Claude SDK 실행, 데스크 관리, Relay 통신
 */

import 'dotenv/config';
import { execSync, spawn, exec } from 'child_process';
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
    // 배포 상태 관리
    this.deployState = {
      active: false,
      requesterId: null,        // 배포 요청한 클라이언트 deviceId
      relayDeploy: false,       // Relay 배포 담당 여부
      preApproved: false,       // 사전 승인 여부
      tasks: {                  // 병렬 빌드 작업 상태
        git: 'waiting',         // waiting, running, done, error
        apk: 'waiting',
        exe: 'waiting',
        npm: 'waiting',
        json: 'waiting'
      },
      ready: false,             // 빌드 완료 여부
      commitHash: null,
      version: null,
      pylonAcks: new Set()      // deploy_start_ack 받은 Pylon들
    };
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

  /**
   * Relay 재연결 및 인증 완료까지 대기
   * @param {number} timeout - 최대 대기 시간 (ms), 기본 60초
   * @returns {Promise<void>}
   */
  waitForRelayReconnect(timeout = 60000) {
    return new Promise((resolve, reject) => {
      const startTime = Date.now();
      const checkInterval = 500; // 0.5초마다 확인

      const check = () => {
        if (this.authenticated) {
          resolve();
          return;
        }

        if (Date.now() - startTime > timeout) {
          reject(new Error('Relay reconnect timeout'));
          return;
        }

        setTimeout(check, checkInterval);
      };

      // 첫 체크는 약간의 딜레이 후 시작 (Relay가 재시작할 시간)
      setTimeout(check, 5000);
    });
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

    // Claude 사용량 요청
    if (type === 'claude_usage_request') {
      this.handleClaudeUsageRequest(message);
      return;
    }

    // 새 배포 시스템
    if (type === 'deploy_prepare') {
      this.handleDeployPrepare(message);
      return;
    }

    if (type === 'deploy_confirm') {
      this.handleDeployConfirm(message);
      return;
    }

    if (type === 'deploy_start') {
      this.handleDeployStart(message);
      return;
    }

    if (type === 'deploy_start_ack') {
      this.handleDeployStartAck(message);
      return;
    }

    if (type === 'deploy_go') {
      this.handleDeployGo(message);
      return;
    }

    // 버전 체크 요청
    if (type === 'version_check_request') {
      this.handleVersionCheckRequest(message);
      return;
    }

    // 앱 업데이트 요청
    if (type === 'app_update_request') {
      this.handleAppUpdateRequest(message);
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

      // commit이 undefined거나 유효하지 않으면 스킵
      if (!deployInfo.commit || deployInfo.commit === 'undefined') {
        this.log('Invalid deploy commit, skipping update');
        return;
      }

      if (localCommit !== deployInfo.commit) {
        this.log('Update available, running p2-update...');

        const result = await this.runScriptAsync('p2-update.ps1', `-Commit ${deployInfo.commit}`);
        if (!result.success) {
          throw new Error(result.message);
        }

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
      try {
        // gh 명령어 사용 (private repo 지원)
        const data = execSync(
          'gh release download deploy --repo SirGrey8209/estelle -p "deploy.json" -O -',
          { encoding: 'utf-8', windowsHide: true }
        );
        resolve(JSON.parse(data));
      } catch {
        resolve(null);
      }
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

  // ============ Claude 사용량 ============

  /**
   * Claude 사용량 요청 처리
   */
  async handleClaudeUsageRequest(message) {
    const from = message.from;
    this.log('Claude usage request received');

    try {
      // ~/.claude/.credentials.json에서 토큰 읽기
      const homeDir = process.env.HOME || process.env.USERPROFILE;
      const credentialsPath = path.join(homeDir, '.claude', '.credentials.json');

      if (!fs.existsSync(credentialsPath)) {
        throw new Error('Credentials file not found');
      }

      const credentials = JSON.parse(fs.readFileSync(credentialsPath, 'utf-8'));
      const accessToken = credentials.claudeAiOauth?.accessToken;

      if (!accessToken) {
        throw new Error('Access token not found in credentials');
      }

      // Anthropic API 호출
      const usage = await this.fetchClaudeUsage(accessToken);

      this.send({
        type: 'claude_usage_result',
        to: from?.deviceId ? { deviceId: from.deviceId, deviceType: from.deviceType } : undefined,
        broadcast: from?.deviceId ? undefined : 'clients',
        payload: usage
      });

    } catch (err) {
      this.log(`Claude usage request failed: ${err.message}`);
      this.send({
        type: 'claude_usage_result',
        to: from?.deviceId ? { deviceId: from.deviceId, deviceType: from.deviceType } : undefined,
        broadcast: from?.deviceId ? undefined : 'clients',
        payload: {
          usage5h: 0,
          usage7d: 0,
          error: err.message
        }
      });
    }
  }

  /**
   * Anthropic API에서 사용량 조회
   */
  fetchClaudeUsage(accessToken) {
    return new Promise((resolve, reject) => {
      const options = {
        hostname: 'api.anthropic.com',
        path: '/api/organizations/usage',
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            if (res.statusCode !== 200) {
              reject(new Error(`API returned ${res.statusCode}: ${data}`));
              return;
            }

            const json = JSON.parse(data);

            // API 응답 파싱
            const usage5h = json.standardRateLimitStatus?.percentConsumed ?? json.usage_5h?.percentage ?? 0;
            const usage7d = json.dailyRateLimitStatus?.percentConsumed ?? json.usage_7d?.percentage ?? 0;
            const resets5h = json.standardRateLimitStatus?.resetsAt ?? json.usage_5h?.resets_at;
            const resets7d = json.dailyRateLimitStatus?.resetsAt ?? json.usage_7d?.resets_at;

            resolve({
              usage5h,
              usage7d,
              resets5h,
              resets7d,
              error: null
            });
          } catch (e) {
            reject(new Error(`Failed to parse response: ${e.message}`));
          }
        });
      });

      req.on('error', reject);
      req.setTimeout(10000, () => {
        req.destroy();
        reject(new Error('Request timeout'));
      });
      req.end();
    });
  }

  // ============ 버전 체크 / 앱 업데이트 ============

  /**
   * 버전 체크 요청 처리
   */
  async handleVersionCheckRequest(message) {
    const from = message.from;
    this.log('Version check request received');

    try {
      // GitHub에서 deploy.json 가져오기
      const deployInfo = await this.fetchDeployJson();

      this.send({
        type: 'version_check_result',
        to: from?.deviceId ? { deviceId: from.deviceId, deviceType: from.deviceType } : undefined,
        broadcast: from?.deviceId ? undefined : 'clients',
        payload: {
          version: deployInfo?.version || null,
          commit: deployInfo?.commit || null,
          buildTime: deployInfo?.buildTime || null,
          apkUrl: deployInfo?.apkUrl || null,
          exeUrl: deployInfo?.exeUrl || null,
          error: null
        }
      });
    } catch (err) {
      this.log(`Version check failed: ${err.message}`);
      this.send({
        type: 'version_check_result',
        to: from?.deviceId ? { deviceId: from.deviceId, deviceType: from.deviceType } : undefined,
        broadcast: from?.deviceId ? undefined : 'clients',
        payload: {
          version: null,
          commit: null,
          error: err.message
        }
      });
    }
  }

  /**
   * 앱 업데이트 요청 처리
   * - 요청자(앱)에게 다운로드 URL 전달
   */
  async handleAppUpdateRequest(message) {
    const from = message.from;
    this.log('App update request received');

    try {
      const deployInfo = await this.fetchDeployJson();

      if (!deployInfo) {
        throw new Error('배포 정보를 가져올 수 없습니다');
      }

      // GitHub Release에서 직접 다운로드 URL 생성
      const baseUrl = 'https://github.com/sirgrey8209/estelle/releases/download/deploy';
      const apkUrl = `${baseUrl}/estelle-app.apk`;
      const exeUrl = `${baseUrl}/estelle-app.exe`;

      this.send({
        type: 'app_update_result',
        to: { deviceId: from.deviceId, deviceType: from.deviceType },
        payload: {
          success: true,
          version: deployInfo.version,
          commit: deployInfo.commit,
          apkUrl,
          exeUrl,
        }
      });
    } catch (err) {
      this.log(`App update request failed: ${err.message}`);
      this.send({
        type: 'app_update_result',
        to: { deviceId: from.deviceId, deviceType: from.deviceType },
        payload: {
          success: false,
          error: err.message
        }
      });
    }
  }

  // ============ 배포 시스템 ============

  /**
   * 배포 상태를 모든 앱에 브로드캐스트
   */
  sendDeployStatus() {
    if (!this.deployState.active) return;

    const { tasks } = this.deployState;
    const statusParts = [];

    const statusMap = {
      'waiting': '대기',
      'running': '진행중',
      'done': '✓',
      'error': '✗'
    };

    if (this.deployState.relayDeploy) {
      statusParts.push(`Git(${statusMap[tasks.git] || tasks.git})`);
      statusParts.push(`APK(${statusMap[tasks.apk] || tasks.apk})`);
      statusParts.push(`EXE(${statusMap[tasks.exe] || tasks.exe})`);
      statusParts.push(`NPM(${statusMap[tasks.npm] || tasks.npm})`);
      if (tasks.json !== 'waiting') {
        statusParts.push(`JSON(${statusMap[tasks.json] || tasks.json})`);
      }
    }

    // 모든 앱에 브로드캐스트
    this.send({
      type: 'deploy_status',
      broadcast: 'apps',
      payload: {
        deviceId: this.deviceId,
        tasks: { ...tasks },
        message: statusParts.join(' ')
      }
    });
  }

  /**
   * 배포 상태 초기화
   */
  resetDeployState() {
    this.deployState = {
      active: false,
      requesterId: null,
      relayDeploy: false,
      preApproved: false,
      tasks: {
        git: 'waiting',
        apk: 'waiting',
        exe: 'waiting',
        npm: 'waiting',
        json: 'waiting'
      },
      ready: false,
      commitHash: null,
      version: null,
      pylonAcks: new Set()
    };
  }

  /**
   * PowerShell 스크립트 실행 헬퍼 (비동기)
   */
  runScriptAsync(scriptName, args = '') {
    return new Promise((resolve, reject) => {
      const scriptPath = path.join(REPO_DIR, 'scripts', scriptName);
      const cmd = `powershell -ExecutionPolicy Bypass -File "${scriptPath}" -RepoDir "${REPO_DIR}" ${args}`;
      exec(cmd, { encoding: 'utf-8', timeout: 600000, maxBuffer: 10 * 1024 * 1024, windowsHide: true }, (error, stdout, stderr) => {
        if (error) {
          try {
            const result = JSON.parse(stdout);
            if (!result.success) reject(new Error(result.message || 'Script failed'));
            else resolve(result);
          } catch (e) {
            reject(new Error(stderr || stdout || error.message));
          }
          return;
        }
        try { resolve(JSON.parse(stdout)); }
        catch (e) { reject(new Error(`Failed to parse JSON: ${stdout}`)); }
      });
    });
  }

  /**
   * PowerShell 스크립트 실행 헬퍼 (비동기 + 실시간 로그 브로드캐스트)
   */
  runScriptWithLog(scriptName, args = '') {
    return new Promise((resolve, reject) => {
      const scriptPath = path.join(REPO_DIR, 'scripts', scriptName);
      const fullArgs = [
        '-ExecutionPolicy', 'Bypass',
        '-File', scriptPath,
        '-RepoDir', REPO_DIR,
        ...args.split(' ').filter(a => a)
      ];

      const child = spawn('powershell', fullArgs, {
        encoding: 'utf-8',
        windowsHide: true
      });

      let stdout = '';
      let stderr = '';

      child.stdout.on('data', (data) => {
        const text = data.toString();
        stdout += text;

        // 각 라인을 deploy_log로 브로드캐스트
        const lines = text.split('\n').filter(line => line.trim());
        for (const line of lines) {
          this.sendDeployLog(line.trim());
        }
      });

      child.stderr.on('data', (data) => {
        const text = data.toString();
        stderr += text;

        // stderr도 로그로 전송
        const lines = text.split('\n').filter(line => line.trim());
        for (const line of lines) {
          this.sendDeployLog(`[ERR] ${line.trim()}`);
        }
      });

      child.on('close', (code) => {
        if (code !== 0) {
          try {
            const result = JSON.parse(stdout);
            if (!result.success) reject(new Error(result.message || 'Script failed'));
            else resolve(result);
          } catch (e) {
            reject(new Error(stderr || stdout || `Exit code: ${code}`));
          }
          return;
        }
        try { resolve(JSON.parse(stdout)); }
        catch (e) { reject(new Error(`Failed to parse JSON: ${stdout}`)); }
      });

      child.on('error', (err) => {
        reject(err);
      });
    });
  }

  /**
   * 배포 로그 한 줄 브로드캐스트
   */
  sendDeployLog(line) {
    this.send({
      type: 'deploy_log',
      broadcast: 'apps',
      payload: {
        deviceId: this.deviceId,
        line,
        timestamp: Date.now()
      }
    });
  }

  /**
   * PowerShell 스크립트 실행 헬퍼 (동기)
   */
  runScript(scriptName, args = '') {
    const scriptPath = path.join(REPO_DIR, 'scripts', scriptName);
    const cmd = `powershell -ExecutionPolicy Bypass -File "${scriptPath}" -RepoDir "${REPO_DIR}" ${args}`;
    const result = execSync(cmd, { encoding: 'utf-8', timeout: 600000, windowsHide: true });
    return JSON.parse(result);
  }

  /**
   * 1단계: 배포 준비 (빌드만, 업로드/배포 X)
   */
  async handleDeployPrepare(message) {
    const { relayDeploy } = message.payload || {};
    const from = message.from;

    this.log(`Deploy prepare requested. relayDeploy: ${relayDeploy}`);

    // 배포 상태 초기화
    this.resetDeployState();
    this.deployState.active = true;
    this.deployState.requesterId = from?.deviceId;
    this.deployState.relayDeploy = relayDeploy || false;

    try {
      // 1. Git sync (P1)
      this.deployState.tasks.git = 'running';
      this.sendDeployStatus();
      this.sendDeployLog('▶ Git sync 시작...');

      this.log('Running git-sync-p1...');
      const gitResult = await this.runScriptWithLog('git-sync-p1.ps1');
      if (!gitResult.success) throw new Error(gitResult.message);

      this.deployState.tasks.git = 'done';
      this.deployState.commitHash = gitResult.commit;
      this.sendDeployStatus();
      this.log(`Git sync completed: ${gitResult.commit}`);

      // 2. APK 빌드 (Relay 배포 담당 Pylon만)
      if (relayDeploy) {
        // buildTime 생성 (YYYYMMDDHHmmss)
        const now = new Date();
        const buildTime = now.getFullYear().toString() +
          (now.getMonth() + 1).toString().padStart(2, '0') +
          now.getDate().toString().padStart(2, '0') +
          now.getHours().toString().padStart(2, '0') +
          now.getMinutes().toString().padStart(2, '0') +
          now.getSeconds().toString().padStart(2, '0');
        this.deployState.buildTime = buildTime;
        this.log(`Build time: ${buildTime}`);

        this.deployState.tasks.apk = 'running';
        this.sendDeployStatus();
        this.sendDeployLog('▶ APK 빌드 시작...');

        this.log('Running build-apk...');
        const apkResult = await this.runScriptWithLog('build-apk.ps1', `-BuildTime ${buildTime}`);
        if (!apkResult.success) throw new Error(apkResult.message);

        this.deployState.tasks.apk = 'done';
        this.sendDeployStatus();
        this.log(`APK build completed: ${apkResult.size}`);

        // 3. EXE 빌드
        this.deployState.tasks.exe = 'running';
        this.sendDeployStatus();
        this.sendDeployLog('▶ EXE 빌드 시작...');

        this.log('Running build-exe...');
        const exeResult = await this.runScriptWithLog('build-exe.ps1', `-BuildTime ${buildTime}`);
        if (!exeResult.success) throw new Error(exeResult.message);

        this.deployState.tasks.exe = 'done';
        this.sendDeployStatus();
        this.log('EXE build completed');
      } else {
        this.deployState.tasks.apk = 'done';
        this.deployState.tasks.exe = 'done';
      }

      // 4. Pylon 빌드 (npm install)
      this.deployState.tasks.npm = 'running';
      this.sendDeployStatus();
      this.sendDeployLog('▶ Pylon 빌드 시작...');

      this.log('Running build-pylon...');
      const pylonResult = await this.runScriptWithLog('build-pylon.ps1');
      if (!pylonResult.success) throw new Error(pylonResult.message);

      this.deployState.tasks.npm = 'done';
      this.sendDeployStatus();
      this.log('Pylon build completed');

      // 5. GitHub에서 deploy.json 버전 가져오기
      try {
        const version = await new Promise((resolve) => {
          exec('"C:\\Program Files\\GitHub CLI\\gh.exe" release download deploy -p "deploy.json" --repo sirgrey8209/estelle -O -',
            { encoding: 'utf-8', timeout: 30000 }, (error, stdout) => {
              if (error || !stdout) { resolve(null); return; }
              try {
                const parsed = JSON.parse(stdout);
                resolve(parsed.version || null);
              } catch { resolve(null); }
            });
        });
        this.deployState.version = version;
      } catch {
        this.deployState.version = null;
      }

      this.deployState.tasks.json = 'done';
      this.sendDeployStatus();

      // 6. 빌드 완료
      this.deployState.ready = true;

      this.send({
        type: 'deploy_ready',
        to: this.deployState.requesterId,
        payload: {
          deviceId: this.deviceId,
          success: true,
          commitHash: this.deployState.commitHash,
          version: this.deployState.version
        }
      });

      this.log('Deploy prepare completed');

      // 사전 승인된 경우 바로 deploy_start 전송
      if (this.deployState.preApproved) {
        this.log('Pre-approved, sending deploy_start immediately');
        this.broadcastDeployStart();
      }

    } catch (err) {
      this.log(`Deploy prepare failed: ${err.message}`);

      // 실패한 태스크 표시
      for (const key of Object.keys(this.deployState.tasks)) {
        if (this.deployState.tasks[key] === 'running') {
          this.deployState.tasks[key] = 'error';
        }
      }
      this.sendDeployStatus();

      this.send({
        type: 'deploy_ready',
        to: this.deployState.requesterId,
        payload: {
          deviceId: this.deviceId,
          success: false,
          error: err.message
        }
      });

      this.resetDeployState();
    }
  }

  /**
   * 사용자 확인 (사전 승인 / 취소 토글)
   */
  handleDeployConfirm(message) {
    const { preApproved, cancel } = message.payload || {};
    const from = message.from;

    if (cancel) {
      this.log('Deploy confirm cancelled');
      this.deployState.preApproved = false;
      return;
    }

    this.log(`Deploy confirm received. preApproved: ${preApproved}`);
    this.deployState.preApproved = true;

    // 이미 빌드 완료된 경우 바로 deploy_start
    if (this.deployState.ready) {
      this.log('Already ready, sending deploy_start');
      this.broadcastDeployStart();
    }
  }

  /**
   * deploy_start 브로드캐스트 (다른 Pylon들에게)
   */
  broadcastDeployStart() {
    this.send({
      type: 'deploy_start',
      broadcast: 'all',
      payload: {
        commitHash: this.deployState.commitHash,
        version: this.deployState.version,
        leadPylonId: this.deviceId
      }
    });
  }

  /**
   * deploy_start 수신 (다른 Pylon)
   * - p2-update 스크립트 실행 후 ack 전송
   */
  async handleDeployStart(message) {
    const { commitHash, version, leadPylonId } = message.payload || {};

    // 주도 Pylon은 무시
    if (leadPylonId === this.deviceId) {
      this.log('I am the lead pylon, ignoring deploy_start');
      return;
    }

    this.log(`Deploy start received. commitHash: ${commitHash}, leadPylon: ${leadPylonId}`);

    try {
      // P2 업데이트 스크립트 실행
      this.log('Running p2-update...');
      const result = await this.runScriptAsync('p2-update.ps1', `-Commit ${commitHash}`);

      if (!result.success) {
        throw new Error(result.message);
      }

      this.log(`P2 update completed. stashId: ${result.stashId || 'none'}`);

      // ack 전송
      this.send({
        type: 'deploy_start_ack',
        to: { deviceId: leadPylonId, deviceType: 'pylon' },
        payload: {
          deviceId: this.deviceId,
          success: true
        }
      });

      this.log('Deploy start ack sent');

    } catch (err) {
      this.log(`Deploy start failed: ${err.message}`);

      this.send({
        type: 'deploy_start_ack',
        to: { deviceId: leadPylonId, deviceType: 'pylon' },
        payload: {
          deviceId: this.deviceId,
          success: false,
          error: err.message
        }
      });
    }
  }

  /**
   * deploy_start_ack 수신 (주도 Pylon)
   */
  handleDeployStartAck(message) {
    const { deviceId, success, error } = message.payload || {};

    this.log(`Deploy start ack from ${deviceId}: ${success ? 'success' : 'failed'}`);

    if (success) {
      this.deployState.pylonAcks.add(deviceId);
    }

    // 모든 Pylon ack 수신 여부 확인 → 클라이언트에게 알림
    // (현재는 단순히 ack 수신했음을 알림, Pylon 목록 관리는 추후)
    this.send({
      type: 'deploy_ack_received',
      to: this.deployState.requesterId,
      payload: {
        deviceId,
        success,
        error,
        totalAcks: this.deployState.pylonAcks.size
      }
    });
  }

  /**
   * 배포 실행 (GO 버튼)
   * - upload-release, deploy-relay, copy-release, 재시작
   */
  async handleDeployGo(message) {
    this.log('Deploy go received');

    try {
      // 주도 Pylon만 업로드 및 fly deploy 수행
      if (this.deployState.relayDeploy) {
        // 1. GitHub Release 업로드 (deploy.json + APK)
        this.log('Uploading to GitHub Release...');
        this.sendDeployLog('▶ GitHub Release 업로드 시작...');
        this.send({
          type: 'deploy_status',
          broadcast: 'all',
          payload: {
            deviceId: this.deviceId,
            tasks: { upload: 'running', relay: 'waiting', copy: 'waiting' },
            message: 'Upload(진행중) Relay(대기) Copy(대기)'
          }
        });

        const uploadResult = await this.runScriptWithLog('upload-release.ps1',
          `-Commit ${this.deployState.commitHash} -Version ${this.deployState.version} -BuildTime ${this.deployState.buildTime}`);
        if (!uploadResult.success) throw new Error(uploadResult.message);
        this.log(`Uploaded: ${uploadResult.uploaded.join(', ')}`);

        // 2. fly deploy
        this.log('Deploying Relay...');
        this.sendDeployLog('▶ Relay 배포 시작...');
        this.send({
          type: 'deploy_status',
          broadcast: 'all',
          payload: {
            deviceId: this.deviceId,
            tasks: { upload: 'done', relay: 'deploying', copy: 'waiting' },
            message: 'Upload(✓) Relay(배포중) Copy(대기)'
          }
        });

        const relayResult = await this.runScriptWithLog('deploy-relay.ps1');
        if (!relayResult.success) throw new Error(relayResult.message);
        this.log('Relay deployed');

        // 3. EXE를 release 폴더로 복사
        this.log('Copying to release folder...');
        this.sendDeployLog('▶ Release 폴더로 복사 시작...');
        this.send({
          type: 'deploy_status',
          broadcast: 'all',
          payload: {
            deviceId: this.deviceId,
            tasks: { upload: 'done', relay: 'done', copy: 'running' },
            message: 'Upload(✓) Relay(✓) Copy(진행중)'
          }
        });

        const copyResult = await this.runScriptWithLog('copy-release.ps1');
        if (!copyResult.success) throw new Error(copyResult.message);
        this.log(`Copied to: ${copyResult.destination}`);

        this.send({
          type: 'deploy_status',
          broadcast: 'all',
          payload: {
            deviceId: this.deviceId,
            tasks: { upload: 'done', relay: 'done', copy: 'done' },
            message: 'Upload(✓) Relay(✓) Copy(✓)'
          }
        });
      }

      // 재시작 시그널
      this.send({
        type: 'deploy_restart',
        broadcast: 'all',
        payload: {}
      });

      // 잠시 대기 후 재시작 (다른 Pylon이 먼저 재시작하도록)
      await new Promise(resolve => setTimeout(resolve, 2000));

      this.log('Starting self-patch...');

      // 연결 종료 예고
      this.send({
        type: 'deploy_restarting',
        payload: { deviceId: this.deviceId },
        broadcast: 'all'
      });

      // 배치파일 경로
      const batchPath = path.join(REPO_DIR, 'estelle-pylon', 'self-patch.bat');

      // 배치파일 생성
      const batchContent = `@echo off
timeout /t 2 /nobreak > nul
cd /d "${path.join(REPO_DIR, 'estelle-pylon')}"
pm2 restart estelle-pylon
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

    } catch (err) {
      this.log(`Deploy go failed: ${err.message}`);

      this.send({
        type: 'deploy_error',
        broadcast: 'all',
        payload: {
          deviceId: this.deviceId,
          error: err.message
        }
      });
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
