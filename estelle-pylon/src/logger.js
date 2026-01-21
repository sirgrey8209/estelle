/**
 * General Logger
 * 일반 로그를 텍스트 형식으로 기록
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const LOG_DIR = path.join(__dirname, '..', 'logs');
const MAX_LOG_FILES = 50;
const LOG_PREFIX = 'pylon-';

let currentFile = null;
let writeStream = null;
let initialized = false;

function initialize() {
  if (initialized) return;

  if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true });
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  currentFile = path.join(LOG_DIR, `${LOG_PREFIX}${timestamp}.log`);
  writeStream = fs.createWriteStream(currentFile, { flags: 'a' });

  cleanupOldLogs();
  initialized = true;
}

function cleanupOldLogs() {
  try {
    const files = fs.readdirSync(LOG_DIR)
      .filter(f => f.startsWith(LOG_PREFIX) && f.endsWith('.log'))
      .sort()
      .reverse();

    if (files.length > MAX_LOG_FILES) {
      const toDelete = files.slice(MAX_LOG_FILES);
      toDelete.forEach(file => {
        fs.unlinkSync(path.join(LOG_DIR, file));
      });
    }
  } catch (err) {
    console.error(`[Logger] Cleanup error: ${err.message}`);
  }
}

function formatTime() {
  return new Date().toISOString();
}

function writeLog(level, ...args) {
  initialize();

  const message = args.map(a =>
    typeof a === 'object' ? JSON.stringify(a) : String(a)
  ).join(' ');

  const line = `[${formatTime()}] [${level}] ${message}\n`;

  if (level === 'ERROR') {
    console.error(line.trim());
  } else {
    console.log(line.trim());
  }

  if (writeStream) {
    writeStream.write(line);
  }
}

export default {
  log: (...args) => writeLog('INFO', ...args),
  info: (...args) => writeLog('INFO', ...args),
  warn: (...args) => writeLog('WARN', ...args),
  error: (...args) => writeLog('ERROR', ...args),
  getCurrentFile: () => currentFile
};
