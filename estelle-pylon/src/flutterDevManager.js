/**
 * Flutter Dev Manager - Flutter 웹 개발 서버 관리
 *
 * 기능:
 * - Pylon당 1개의 Flutter 웹 서버 관리
 * - 시작 시 기존 프로세스 정리 (포트 점유 해제)
 * - Hot Reload / Hot Restart 트리거
 * - 서버 상태 모니터링
 */

import { spawn, execSync } from 'child_process';
import path from 'path';

const FLUTTER_PATH = 'C:\\flutter\\bin\\flutter.bat';
const DEFAULT_PORT = 8080;
const MAX_LOG_LINES = 100;

/**
 * Flutter Dev Manager 클래스
 * Pylon당 1개의 서버만 관리
 */
class FlutterDevManager {
  constructor(onEvent) {
    this.onEvent = onEvent;
    this.server = null;  // 단일 서버 상태
    this.appDir = null;  // Flutter 앱 디렉토리
  }

  /**
   * 초기화 - 기존 프로세스 정리
   */
  async initialize(appDir) {
    this.appDir = appDir;
    console.log(`[FlutterDev] Initializing with appDir: ${appDir}`);

    // 기존 포트 점유 프로세스 정리
    await this.killExistingProcess(DEFAULT_PORT);
  }

  /**
   * 포트를 점유 중인 프로세스 kill (Windows)
   */
  async killExistingProcess(port) {
    try {
      // netstat로 포트 사용 중인 PID 찾기
      const result = execSync(`netstat -ano | findstr :${port} | findstr LISTENING`, {
        encoding: 'utf-8',
        windowsHide: true,
      });

      const lines = result.trim().split('\n');
      const pids = new Set();

      for (const line of lines) {
        const parts = line.trim().split(/\s+/);
        const pid = parts[parts.length - 1];
        if (pid && !isNaN(parseInt(pid))) {
          pids.add(pid);
        }
      }

      for (const pid of pids) {
        try {
          console.log(`[FlutterDev] Killing process ${pid} on port ${port}`);
          execSync(`taskkill /PID ${pid} /F`, { windowsHide: true });
        } catch (e) {
          // 이미 종료됐거나 권한 없음
          console.log(`[FlutterDev] Failed to kill PID ${pid}: ${e.message}`);
        }
      }
    } catch (e) {
      // 포트 사용 중인 프로세스 없음 (정상)
      console.log(`[FlutterDev] No existing process on port ${port}`);
    }
  }

  /**
   * 이벤트 발행
   */
  emitEvent(event) {
    console.log(`[FlutterDev] Event:`, event);
    if (this.onEvent) {
      this.onEvent(event);
    }
  }

  /**
   * 로그 추가 (circular buffer)
   */
  appendLog(text) {
    if (!this.server) return;

    const lines = text.split('\n').filter(line => line.trim());
    for (const line of lines) {
      this.server.logs.push({
        timestamp: Date.now(),
        text: line.trim()
      });

      // 최대 로그 라인 유지
      if (this.server.logs.length > MAX_LOG_LINES) {
        this.server.logs.shift();
      }
    }
  }

  /**
   * 서버 시작
   */
  async start(options = {}) {
    const { port = DEFAULT_PORT } = options;

    if (!this.appDir) {
      return { success: false, error: 'appDir not set. Call initialize() first.' };
    }

    // 이미 실행 중인지 확인
    if (this.server && this.server.status === 'running') {
      return {
        success: false,
        error: 'Server already running',
        url: this.server.url
      };
    }

    // 기존 프로세스 정리
    if (this.server && this.server.process) {
      try {
        this.server.process.kill();
      } catch (e) {
        // ignore
      }
    }

    // 포트 점유 프로세스 정리
    await this.killExistingProcess(port);

    this.server = {
      status: 'starting',
      port,
      url: `http://localhost:${port}`,
      startedAt: new Date(),
      lastReload: null,
      logs: [],
      errorCount: 0,
      process: null,
    };

    this.emitEvent({ type: 'server_starting', url: this.server.url });

    return new Promise((resolve) => {
      try {
        // Flutter 실행
        const child = spawn(FLUTTER_PATH, [
          'run',
          '-d', 'web-server',
          '--web-port', String(port),
        ], {
          cwd: this.appDir,
          shell: true,
          stdio: ['pipe', 'pipe', 'pipe'],
          windowsHide: true,
        });

        this.server.process = child;

        let resolved = false;
        const resolveOnce = (result) => {
          if (!resolved) {
            resolved = true;
            resolve(result);
          }
        };

        // stdout 처리
        child.stdout.on('data', (data) => {
          const text = data.toString();
          this.appendLog(text);

          // 서버 시작 완료 감지
          if (text.includes('is being served at') || text.includes('lib/main.dart')) {
            this.server.status = 'running';
            this.emitEvent({ type: 'server_ready', url: this.server.url });
            resolveOnce({ success: true, url: this.server.url });
          }

          // Hot Reload 완료 감지
          if (text.includes('Reloaded') || text.includes('Performing hot reload')) {
            this.server.lastReload = new Date();
            this.emitEvent({ type: 'reload_complete' });
          }

          // Hot Restart 완료 감지
          if (text.includes('Restarted application')) {
            this.server.lastReload = new Date();
            this.emitEvent({ type: 'restart_complete' });
          }
        });

        // stderr 처리
        child.stderr.on('data', (data) => {
          const text = data.toString();
          this.appendLog(`[ERR] ${text}`);

          if (text.includes('Error') || text.includes('Exception')) {
            this.server.errorCount++;
            this.emitEvent({ type: 'error', error: text.trim() });
          }
        });

        // 프로세스 종료 처리
        child.on('exit', (code, signal) => {
          console.log(`[FlutterDev] Process exited: code=${code}, signal=${signal}`);

          if (this.server && this.server.status === 'running' && code !== 0) {
            this.server.status = 'crashed';
            this.emitEvent({ type: 'server_crashed', exitCode: code });
          } else if (this.server) {
            this.server.status = 'stopped';
            this.emitEvent({ type: 'server_stopped' });
          }

          resolveOnce({ success: false, error: `Process exited with code ${code}` });
        });

        child.on('error', (err) => {
          console.error(`[FlutterDev] Process error:`, err);
          if (this.server) {
            this.server.status = 'crashed';
          }
          this.emitEvent({ type: 'server_crashed', error: err.message });
          resolveOnce({ success: false, error: err.message });
        });

        // 타임아웃 (30초 내에 시작되지 않으면)
        setTimeout(() => {
          if (this.server && this.server.status === 'starting') {
            this.server.status = 'running';
            resolveOnce({ success: true, url: this.server.url, note: 'Assumed running after timeout' });
          }
        }, 30000);

      } catch (err) {
        console.error(`[FlutterDev] Failed to start:`, err);
        if (this.server) {
          this.server.status = 'crashed';
        }
        resolve({ success: false, error: err.message });
      }
    });
  }

  /**
   * 서버 중지
   */
  stop() {
    if (!this.server) {
      return { success: false, error: 'No server found' };
    }

    if (this.server.status !== 'running' && this.server.status !== 'starting') {
      return { success: false, error: `Server is ${this.server.status}` };
    }

    try {
      // 정상 종료 시도 ('q' 명령)
      if (this.server.process && this.server.process.stdin) {
        this.server.process.stdin.write('q');
      }

      // 3초 후 강제 종료
      setTimeout(() => {
        if (this.server && this.server.process && !this.server.process.killed) {
          this.server.process.kill('SIGTERM');
        }
      }, 3000);

      this.server.status = 'stopped';
      return { success: true };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }

  /**
   * stdin으로 명령 전송
   */
  sendCommand(command) {
    if (!this.server) {
      return { success: false, error: 'No server found' };
    }

    if (this.server.status !== 'running') {
      return { success: false, error: `Server is ${this.server.status}` };
    }

    if (!this.server.process || !this.server.process.stdin) {
      return { success: false, error: 'No stdin available' };
    }

    try {
      this.server.process.stdin.write(command);
      return { success: true, command };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }

  /**
   * Hot Reload
   */
  hotReload() {
    const result = this.sendCommand('r');
    if (result.success) {
      this.emitEvent({ type: 'reload_triggered' });
    }
    return { ...result, action: 'Hot Reload' };
  }

  /**
   * Hot Restart
   */
  hotRestart() {
    const result = this.sendCommand('R');
    if (result.success) {
      this.emitEvent({ type: 'restart_triggered' });
    }
    return { ...result, action: 'Hot Restart' };
  }

  /**
   * 서버 상태 조회
   */
  getStatus() {
    if (!this.server) {
      return {
        running: false,
        status: 'not_started',
        url: null,
        port: null,
      };
    }

    return {
      running: this.server.status === 'running',
      status: this.server.status,
      url: this.server.url,
      port: this.server.port,
      startedAt: this.server.startedAt,
      lastReload: this.server.lastReload,
      errorCount: this.server.errorCount,
      recentLogs: this.server.logs.slice(-10),
    };
  }

  /**
   * 정리 (Pylon 종료 시)
   */
  cleanup() {
    if (this.server && this.server.process) {
      try {
        this.server.process.kill();
      } catch (e) {
        // ignore
      }
    }
    this.server = null;
  }
}

export default FlutterDevManager;
