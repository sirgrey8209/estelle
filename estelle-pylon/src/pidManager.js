const fs = require('fs');
const path = require('path');
const logger = require('./logger');

const PID_FILE = path.join(__dirname, '..', 'pylon.pid');

class PidManager {
  // 기존 프로세스 종료 후 새 PID 저장
  static initialize() {
    // 기존 PID 파일 확인
    if (fs.existsSync(PID_FILE)) {
      const oldPid = fs.readFileSync(PID_FILE, 'utf-8').trim();
      logger.log(`[PID] Found existing PID file: ${oldPid}`);

      // 기존 프로세스 종료 시도
      try {
        process.kill(parseInt(oldPid), 0); // 프로세스 존재 확인
        logger.log(`[PID] Killing existing process: ${oldPid}`);
        process.kill(parseInt(oldPid), 'SIGTERM');
      } catch (err) {
        // 프로세스가 이미 없음
        logger.log(`[PID] Previous process not running`);
      }
    }

    // 새 PID 저장
    const currentPid = process.pid;
    fs.writeFileSync(PID_FILE, String(currentPid));
    logger.log(`[PID] Current process ID: ${currentPid}`);

    // 종료 시 PID 파일 삭제
    process.on('exit', () => {
      PidManager.cleanup();
    });
    process.on('SIGINT', () => {
      PidManager.cleanup();
      process.exit(0);
    });
    process.on('SIGTERM', () => {
      PidManager.cleanup();
      process.exit(0);
    });

    return currentPid;
  }

  // PID 파일 삭제
  static cleanup() {
    try {
      if (fs.existsSync(PID_FILE)) {
        fs.unlinkSync(PID_FILE);
        logger.log(`[PID] Removed PID file`);
      }
    } catch (err) {
      // 무시
    }
  }

  // 현재 PID 반환
  static getPid() {
    if (fs.existsSync(PID_FILE)) {
      return fs.readFileSync(PID_FILE, 'utf-8').trim();
    }
    return null;
  }

  // PID 파일 경로 반환
  static getPidFilePath() {
    return PID_FILE;
  }
}

module.exports = PidManager;
