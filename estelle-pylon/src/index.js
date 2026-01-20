require('dotenv').config();
const { execSync } = require('child_process');
const path = require('path');
const https = require('https');
const logger = require('./logger');
const RelayClient = require('./relayClient');
const LocalServer = require('./localServer');
const PidManager = require('./pidManager');
const CommandWatcher = require('./commandWatcher');

// 설정
const RELAY_URL = process.env.RELAY_URL || 'ws://localhost:8080';
const LOCAL_PORT = parseInt(process.env.LOCAL_PORT) || 9000;
const DEVICE_ID = process.env.DEVICE_ID || `pylon-${Date.now()}`;
const REPO_DIR = path.resolve(__dirname, '..', '..');
const DEPLOY_JSON_URL = 'https://github.com/sirgrey8209/estelle/releases/download/deploy/deploy.json';

class Pylon {
  constructor() {
    this.deviceId = DEVICE_ID;
    this.relayClient = null;
    this.localServer = null;
    this.commandWatcher = null;
  }

  async start() {
    // PID 관리 초기화 (기존 프로세스 종료)
    PidManager.initialize();

    logger.log(`[${new Date().toISOString()}] [Estelle Pylon v1.1] Starting...`);
    logger.log(`[${new Date().toISOString()}] Device ID: ${this.deviceId}`);
    logger.log(`[${new Date().toISOString()}] Relay URL: ${RELAY_URL}`);
    logger.log(`[${new Date().toISOString()}] Local Port: ${LOCAL_PORT}`);

    // 시작 시 자동 업데이트 체크
    await this.checkAndUpdate();

    // Relay 클라이언트 초기화
    this.relayClient = new RelayClient(RELAY_URL, this.deviceId);

    // 로컬 서버 초기화 (Desktop 통신용)
    this.localServer = new LocalServer(LOCAL_PORT);
    this.localServer.setRelayClient(this.relayClient);

    // Relay 연결 상태 변경 시 Desktop에 알림
    this.relayClient.onStatusChange((isConnected) => {
      this.localServer.sendRelayStatus(isConnected);
    });

    // Relay에서 메시지 수신 시 처리
    this.relayClient.onMessage((data) => {
      // 업데이트 요청 처리
      if (data.type === 'update') {
        this.handleUpdate(data);
        return;
      }

      // Desktop으로 전달
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

      // 채팅 메시지 Relay로 전송
      if (data.type === 'chat') {
        this.relayClient.send({
          type: 'chat',
          message: data.message
        });
      }

      // 디바이스 목록 요청
      if (data.type === 'getDevices') {
        this.relayClient.send({
          type: 'getDevices'
        });
      }

      // Relay로 직접 전달
      if (data.type === 'toRelay') {
        this.relayClient.send(data.data);
      }

      // Git 커밋 요청
      if (data.type === 'getGitCommit') {
        try {
          const commit = execSync('git rev-parse --short HEAD', {
            cwd: REPO_DIR,
            encoding: 'utf-8'
          }).trim();
          ws.send(JSON.stringify({
            type: 'gitCommit',
            commit: commit
          }));
        } catch (err) {
          ws.send(JSON.stringify({
            type: 'gitCommit',
            commit: null,
            error: err.message
          }));
        }
      }

      // 배포 실행 요청
      if (data.type === 'runDeploy') {
        this.handleDeploy(data, ws);
      }
    });

    // 시작
    this.localServer.start();
    this.relayClient.connect();

    // 명령 파일 감시 시작
    this.commandWatcher = new CommandWatcher(this);
    this.commandWatcher.start();

    // Graceful shutdown
    process.on('SIGINT', () => {
      logger.log(`\n[${new Date().toISOString()}] Shutting down...`);
      process.exit(0);
    });
  }

  handleDeploy(data, ws) {
    logger.log(`[${new Date().toISOString()}] Deploy requested, force: ${data.force}`);

    try {
      const scriptPath = path.join(REPO_DIR, 'scripts', 'deploy.ps1');
      const args = data.force ? '-Force' : '';

      // PowerShell로 deploy.ps1 실행
      const result = execSync(
        `powershell -ExecutionPolicy Bypass -File "${scriptPath}" ${args}`,
        {
          cwd: REPO_DIR,
          encoding: 'utf-8',
          timeout: 300000  // 5분 타임아웃
        }
      );

      logger.log(result);

      ws.send(JSON.stringify({
        type: 'deployResult',
        success: true,
        message: 'Deploy completed'
      }));

      // 배포 완료 후 Relay에 알림 전파
      this.relayClient.send({
        type: 'deploy',
        deploy: this.getDeployInfo()
      });

    } catch (err) {
      logger.error(`[${new Date().toISOString()}] Deploy failed:`, err.message);
      ws.send(JSON.stringify({
        type: 'deployResult',
        success: false,
        message: err.message
      }));
    }
  }

  getDeployInfo() {
    try {
      const deployJsonPath = path.join(REPO_DIR, 'deploy.json');
      const fs = require('fs');
      if (fs.existsSync(deployJsonPath)) {
        return JSON.parse(fs.readFileSync(deployJsonPath, 'utf-8'));
      }
    } catch (err) {
      logger.error('Failed to read deploy.json:', err.message);
    }
    return null;
  }

  // 시작 시 deploy.json 체크하여 자동 업데이트
  async checkAndUpdate() {
    logger.log(`[${new Date().toISOString()}] Checking for updates...`);

    try {
      // 현재 로컬 커밋
      const localCommit = execSync('git rev-parse --short HEAD', {
        cwd: REPO_DIR,
        encoding: 'utf-8'
      }).trim();
      logger.log(`[${new Date().toISOString()}] Local commit: ${localCommit}`);

      // deploy.json 가져오기
      const deployInfo = await this.fetchDeployJson();
      if (!deployInfo) {
        logger.log(`[${new Date().toISOString()}] No deploy info found, skipping update`);
        return;
      }

      logger.log(`[${new Date().toISOString()}] Deployed commit: ${deployInfo.commit}`);
      logger.log(`[${new Date().toISOString()}] Deployed version: ${deployInfo.pylon}`);

      // 커밋이 다르면 업데이트
      if (localCommit !== deployInfo.commit) {
        logger.log(`[${new Date().toISOString()}] Update available, syncing to deployed version...`);

        // git fetch
        execSync('git fetch origin', { cwd: REPO_DIR, encoding: 'utf-8' });

        // 배포된 커밋으로 체크아웃
        execSync(`git checkout ${deployInfo.commit}`, { cwd: REPO_DIR, encoding: 'utf-8' });

        // npm install (package-lock.json 변경 가능성)
        const pylonDir = path.join(REPO_DIR, 'estelle-pylon');
        logger.log(`[${new Date().toISOString()}] Running npm install...`);
        execSync('npm install', { cwd: pylonDir, encoding: 'utf-8' });

        logger.log(`[${new Date().toISOString()}] Updated to ${deployInfo.commit}, restarting...`);

        // 재시작 (Task Scheduler가 다시 시작)
        setTimeout(() => {
          process.exit(0);
        }, 1000);
        return;
      }

      logger.log(`[${new Date().toISOString()}] Already up to date`);

    } catch (err) {
      logger.error(`[${new Date().toISOString()}] Update check failed:`, err.message);
      // 업데이트 실패해도 계속 실행
    }
  }

  // deploy.json 가져오기
  fetchDeployJson() {
    return new Promise((resolve) => {
      const url = `${DEPLOY_JSON_URL}?t=${Date.now()}`;

      https.get(url, { headers: { 'User-Agent': 'Estelle-Pylon' } }, (res) => {
        // GitHub redirect 처리
        if (res.statusCode === 302 || res.statusCode === 301) {
          https.get(res.headers.location, (res2) => {
            let data = '';
            res2.on('data', chunk => data += chunk);
            res2.on('end', () => {
              try {
                resolve(JSON.parse(data));
              } catch (e) {
                resolve(null);
              }
            });
          }).on('error', () => resolve(null));
          return;
        }

        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            resolve(null);
          }
        });
      }).on('error', () => resolve(null));
    });
  }

  handleUpdate(data) {
    logger.log(`[${new Date().toISOString()}] Update requested by: ${data.from}`);

    try {
      // git fetch
      logger.log(`[${new Date().toISOString()}] Running git fetch...`);
      execSync('git fetch origin', { cwd: REPO_DIR, encoding: 'utf-8' });

      // 변경 확인
      const diffResult = execSync('git diff HEAD origin/master --quiet', {
        cwd: REPO_DIR,
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe']
      });

      // 변경 없음
      this.relayClient.send({
        type: 'updateResult',
        success: true,
        message: 'Already up to date'
      });
      logger.log(`[${new Date().toISOString()}] Already up to date`);

    } catch (err) {
      // git diff가 변경 있을 때 exit code 1 반환
      if (err.status === 1) {
        try {
          // git pull
          logger.log(`[${new Date().toISOString()}] Changes detected, running git pull...`);
          const pullResult = execSync('git pull origin master', { cwd: REPO_DIR, encoding: 'utf-8' });
          logger.log(pullResult);

          // package-lock.json 변경 확인 후 npm install
          const pylonDir = path.join(REPO_DIR, 'estelle-pylon');
          try {
            execSync('git diff HEAD~1 --name-only | findstr package-lock.json', {
              cwd: REPO_DIR,
              encoding: 'utf-8'
            });
            logger.log(`[${new Date().toISOString()}] package-lock.json changed, running npm install...`);
            execSync('npm install', { cwd: pylonDir, encoding: 'utf-8' });
          } catch (e) {
            // package-lock.json 변경 없음
          }

          // 결과 전송
          this.relayClient.send({
            type: 'updateResult',
            success: true,
            message: 'Updated successfully. Restarting...'
          });

          // 재시작 (Task Scheduler가 다시 시작함)
          logger.log(`[${new Date().toISOString()}] Restarting Pylon...`);
          setTimeout(() => {
            process.exit(0);
          }, 1000);

        } catch (pullErr) {
          logger.error(`[${new Date().toISOString()}] Update failed:`, pullErr.message);
          this.relayClient.send({
            type: 'updateResult',
            success: false,
            message: `Update failed: ${pullErr.message}`
          });
        }
      } else {
        logger.error(`[${new Date().toISOString()}] Git error:`, err.message);
        this.relayClient.send({
          type: 'updateResult',
          success: false,
          message: `Git error: ${err.message}`
        });
      }
    }
  }
}

// 직접 실행 시
if (require.main === module) {
  const pylon = new Pylon();
  pylon.start().catch(err => {
    logger.error(`[${new Date().toISOString()}] Fatal error:`, err);
    process.exit(1);
  });
}

module.exports = Pylon;
