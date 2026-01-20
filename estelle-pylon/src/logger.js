const fs = require('fs');
const path = require('path');

const LOG_DIR = path.join(__dirname, '..', 'logs');
const LOG_FILE = path.join(LOG_DIR, 'pylon.log');

// 로그 디렉토리 생성
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

function formatTime() {
  return new Date().toISOString();
}

function writeLog(level, ...args) {
  const message = args.map(a =>
    typeof a === 'object' ? JSON.stringify(a) : String(a)
  ).join(' ');

  const line = `[${formatTime()}] [${level}] ${message}\n`;

  // 콘솔 출력
  if (level === 'ERROR') {
    console.error(line.trim());
  } else {
    console.log(line.trim());
  }

  // 파일 출력
  fs.appendFileSync(LOG_FILE, line);
}

module.exports = {
  log: (...args) => writeLog('INFO', ...args),
  info: (...args) => writeLog('INFO', ...args),
  warn: (...args) => writeLog('WARN', ...args),
  error: (...args) => writeLog('ERROR', ...args),
  LOG_FILE
};
