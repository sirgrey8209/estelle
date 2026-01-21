/**
 * File-based Message Simulator
 * Relay 없이 파일로 메시지 송수신 시뮬레이션
 */

import fs from 'fs';
import path from 'path';

class FileSimulator {
  constructor(baseDir, options = {}) {
    this.baseDir = baseDir;
    this.inboxDir = path.join(baseDir, 'inbox');
    this.outboxDir = path.join(baseDir, 'outbox');
    this.processedDir = path.join(baseDir, 'processed');

    this.enabled = options.enabled ?? false;
    this.pollInterval = options.pollInterval ?? 1000;
    this.onMessage = options.onMessage || (() => {});
    this.messageCounter = 0;
    this.pollTimer = null;

    this.log = options.log || console.log;
  }

  initialize() {
    if (!this.enabled) return;

    [this.inboxDir, this.outboxDir, this.processedDir].forEach(dir => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    });

    const readmePath = path.join(this.baseDir, 'README.txt');
    if (!fs.existsSync(readmePath)) {
      fs.writeFileSync(readmePath, `
File Simulator for Estelle
==========================

inbox/     - Drop JSON files here to simulate incoming messages
outbox/    - Outgoing messages are written here
processed/ - Processed inbox files are moved here

Example:
  echo '{"type":"desk_list"}' > inbox/test.json
`.trim());
    }

    this.log(`[FileSimulator] Initialized at ${this.baseDir}`);
    this.startPolling();
  }

  startPolling() {
    if (this.pollTimer) return;

    this.pollTimer = setInterval(() => {
      this.checkInbox();
    }, this.pollInterval);

    this.log(`[FileSimulator] Polling inbox every ${this.pollInterval}ms`);
  }

  stop() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
  }

  checkInbox() {
    if (!fs.existsSync(this.inboxDir)) return;

    try {
      const files = fs.readdirSync(this.inboxDir)
        .filter(f => f.endsWith('.json'))
        .sort();

      for (const file of files) {
        const filePath = path.join(this.inboxDir, file);

        try {
          const content = fs.readFileSync(filePath, 'utf-8');
          const message = JSON.parse(content);

          this.log(`[FileSimulator] Processing: ${file}`);
          this.onMessage(message);

          const processedPath = path.join(this.processedDir, `${Date.now()}_${file}`);
          fs.renameSync(filePath, processedPath);

        } catch (err) {
          this.log(`[FileSimulator] Error processing ${file}: ${err.message}`);
          const errorPath = path.join(this.processedDir, `${Date.now()}_${file}.error`);
          fs.renameSync(filePath, errorPath);
        }
      }
    } catch (err) {
      this.log(`[FileSimulator] Error checking inbox: ${err.message}`);
    }
  }

  writeMessage(message) {
    if (!this.enabled) return;

    try {
      this.messageCounter++;
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `${timestamp}_${this.messageCounter}_${message.type || 'unknown'}.json`;
      const filePath = path.join(this.outboxDir, filename);

      fs.writeFileSync(filePath, JSON.stringify(message, null, 2));

    } catch (err) {
      this.log(`[FileSimulator] Error writing message: ${err.message}`);
    }
  }

  clearOutbox() {
    if (!fs.existsSync(this.outboxDir)) return;

    try {
      const files = fs.readdirSync(this.outboxDir);
      for (const file of files) {
        fs.unlinkSync(path.join(this.outboxDir, file));
      }
      this.log(`[FileSimulator] Cleared ${files.length} files from outbox`);
    } catch (err) {
      this.log(`[FileSimulator] Error clearing outbox: ${err.message}`);
    }
  }

  clearProcessed() {
    if (!fs.existsSync(this.processedDir)) return;

    try {
      const files = fs.readdirSync(this.processedDir);
      for (const file of files) {
        fs.unlinkSync(path.join(this.processedDir, file));
      }
      this.log(`[FileSimulator] Cleared ${files.length} files from processed`);
    } catch (err) {
      this.log(`[FileSimulator] Error clearing processed: ${err.message}`);
    }
  }
}

export default FileSimulator;
