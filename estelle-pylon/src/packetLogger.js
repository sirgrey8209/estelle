/**
 * Packet Logger
 * 모든 수신/송신 패킷을 JSON Lines 형식으로 로깅
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const LOG_DIR = path.join(__dirname, '..', 'logs');
const MAX_LOG_FILES = 50;
const LOG_PREFIX = 'packets-';

class PacketLogger {
  constructor() {
    this.currentFile = null;
    this.writeStream = null;
    this.initialized = false;
  }

  initialize() {
    if (this.initialized) return;

    if (!fs.existsSync(LOG_DIR)) {
      fs.mkdirSync(LOG_DIR, { recursive: true });
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    this.currentFile = path.join(LOG_DIR, `${LOG_PREFIX}${timestamp}.jsonl`);
    this.writeStream = fs.createWriteStream(this.currentFile, { flags: 'a' });

    this.cleanupOldLogs();
    this.initialized = true;
  }

  cleanupOldLogs() {
    try {
      const files = fs.readdirSync(LOG_DIR)
        .filter(f => f.startsWith(LOG_PREFIX) && f.endsWith('.jsonl'))
        .sort()
        .reverse();

      if (files.length > MAX_LOG_FILES) {
        const toDelete = files.slice(MAX_LOG_FILES);
        toDelete.forEach(file => {
          fs.unlinkSync(path.join(LOG_DIR, file));
        });
      }
    } catch (err) {
      console.error(`[PacketLogger] Cleanup error: ${err.message}`);
    }
  }

  ensureStream() {
    if (!this.initialized) {
      this.initialize();
    }
    return this.writeStream;
  }

  logRecv(source, data) {
    this.write({
      timestamp: new Date().toISOString(),
      direction: 'recv',
      source,
      type: data?.type || 'unknown',
      data
    });
  }

  logSend(target, data) {
    this.write({
      timestamp: new Date().toISOString(),
      direction: 'send',
      target,
      type: data?.type || 'unknown',
      data
    });
  }

  write(logEntry) {
    try {
      const stream = this.ensureStream();
      stream.write(JSON.stringify(logEntry) + '\n');
    } catch (err) {
      console.error(`[PacketLogger] Write error: ${err.message}`);
    }
  }

  close() {
    if (this.writeStream) {
      this.writeStream.end();
      this.writeStream = null;
    }
  }
}

const packetLogger = new PacketLogger();
export default packetLogger;
