const fs = require('fs');
const path = require('path');
const logger = require('./logger');

const COMMAND_FILE = path.join(__dirname, '..', 'commands.json');
const RESULT_FILE = path.join(__dirname, '..', 'results.json');

class CommandWatcher {
  constructor(pylon) {
    this.pylon = pylon;
    this.watcher = null;
    this.lastProcessed = 0;
  }

  start() {
    // 시작 시 기존 파일 초기화
    this.clearFiles();

    // 파일 watch 시작
    logger.log(`[CommandWatcher] Watching: ${COMMAND_FILE}`);

    // 폴더 watch (파일이 없을 수도 있으므로)
    const watchDir = path.dirname(COMMAND_FILE);

    this.watcher = fs.watch(watchDir, (eventType, filename) => {
      if (filename === 'commands.json') {
        this.processCommands();
      }
    });

    // 주기적 체크 (watch가 실패할 수 있으므로)
    setInterval(() => {
      this.processCommands();
    }, 1000);
  }

  stop() {
    if (this.watcher) {
      this.watcher.close();
      this.watcher = null;
    }
  }

  clearFiles() {
    try {
      if (fs.existsSync(COMMAND_FILE)) {
        fs.unlinkSync(COMMAND_FILE);
      }
      if (fs.existsSync(RESULT_FILE)) {
        fs.unlinkSync(RESULT_FILE);
      }
    } catch (err) {
      // 무시
    }
  }

  processCommands() {
    if (!fs.existsSync(COMMAND_FILE)) {
      return;
    }

    try {
      const content = fs.readFileSync(COMMAND_FILE, 'utf-8');
      const commands = JSON.parse(content);

      // 이미 처리한 명령은 스킵
      if (commands.timestamp && commands.timestamp <= this.lastProcessed) {
        return;
      }

      this.lastProcessed = commands.timestamp || Date.now();
      logger.log(`[CommandWatcher] Processing command: ${commands.command}`);

      // 명령 실행
      const result = this.executeCommand(commands);

      // 결과 저장
      this.writeResult(result);

      // 명령 파일 삭제
      fs.unlinkSync(COMMAND_FILE);

    } catch (err) {
      logger.error(`[CommandWatcher] Error:`, err.message);
    }
  }

  executeCommand(cmd) {
    const result = {
      timestamp: Date.now(),
      command: cmd.command,
      success: false,
      data: null,
      error: null
    };

    try {
      switch (cmd.command) {
        case 'status':
          result.data = {
            pid: process.pid,
            deviceId: this.pylon.deviceId,
            relayConnected: this.pylon.relayClient?.getStatus() || false,
            desktopClients: this.pylon.localServer?.clients?.size || 0,
            uptime: process.uptime()
          };
          result.success = true;
          break;

        case 'echo':
          if (this.pylon.relayClient?.getStatus()) {
            this.pylon.relayClient.send({
              type: 'echo',
              from: this.pylon.deviceId,
              payload: cmd.payload || 'test'
            });
            result.data = { sent: true, payload: cmd.payload };
            result.success = true;
          } else {
            result.error = 'Not connected to Relay';
          }
          break;

        case 'send':
          if (this.pylon.relayClient?.getStatus()) {
            this.pylon.relayClient.send({
              type: cmd.type || 'message',
              from: this.pylon.deviceId,
              ...cmd.data
            });
            result.data = { sent: true };
            result.success = true;
          } else {
            result.error = 'Not connected to Relay';
          }
          break;

        case 'notify':
          const desktopCount = this.pylon.localServer?.clients?.size || 0;
          if (desktopCount > 0) {
            this.pylon.localServer.broadcast({
              type: 'notification',
              title: cmd.title || 'Estelle',
              message: cmd.message
            });
            result.data = { notified: desktopCount };
            result.success = true;
          } else {
            result.error = 'No Desktop clients connected';
          }
          break;

        case 'broadcast':
          this.pylon.localServer?.broadcast(cmd.data);
          result.data = { broadcasted: true };
          result.success = true;
          break;

        case 'restart':
          result.data = { restarting: true };
          result.success = true;
          setTimeout(() => process.exit(0), 1000);
          break;

        case 'stop':
          result.data = { stopping: true };
          result.success = true;
          setTimeout(() => process.exit(0), 500);
          break;

        default:
          result.error = `Unknown command: ${cmd.command}`;
      }
    } catch (err) {
      result.error = err.message;
    }

    return result;
  }

  writeResult(result) {
    try {
      fs.writeFileSync(RESULT_FILE, JSON.stringify(result, null, 2));
      logger.log(`[CommandWatcher] Result written: ${result.success ? 'success' : 'failed'}`);
    } catch (err) {
      logger.error(`[CommandWatcher] Failed to write result:`, err.message);
    }
  }

  // 명령 파일 경로
  static getCommandFilePath() {
    return COMMAND_FILE;
  }

  // 결과 파일 경로
  static getResultFilePath() {
    return RESULT_FILE;
  }
}

module.exports = CommandWatcher;
