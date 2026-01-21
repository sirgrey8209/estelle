import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import logger from './logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PID_FILE = path.join(__dirname, '..', 'pylon.pid');

class PidManager {
  static initialize() {
    if (fs.existsSync(PID_FILE)) {
      const oldPid = fs.readFileSync(PID_FILE, 'utf-8').trim();
      logger.log(`[PID] Found existing PID file: ${oldPid}`);

      try {
        process.kill(parseInt(oldPid), 0);
        logger.log(`[PID] Killing existing process: ${oldPid}`);
        process.kill(parseInt(oldPid), 'SIGTERM');
      } catch (err) {
        logger.log(`[PID] Previous process not running`);
      }
    }

    const currentPid = process.pid;
    fs.writeFileSync(PID_FILE, String(currentPid));
    logger.log(`[PID] Current process ID: ${currentPid}`);

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

  static getPid() {
    if (fs.existsSync(PID_FILE)) {
      return fs.readFileSync(PID_FILE, 'utf-8').trim();
    }
    return null;
  }

  static getPidFilePath() {
    return PID_FILE;
  }
}

export default PidManager;
