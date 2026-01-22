/**
 * Message Store - 데스크별 메시지 히스토리 저장
 * 메모리 캐시 + Debounced 파일 저장 + 페이징 지원
 */

import fs from 'fs';
import path from 'path';

const MESSAGES_DIR = path.join(process.cwd(), 'messages');
const MAX_MESSAGES_PER_DESK = 200;
const SAVE_DEBOUNCE_MS = 2000; // 2초 debounce

// 디렉토리 생성
if (!fs.existsSync(MESSAGES_DIR)) {
  fs.mkdirSync(MESSAGES_DIR, { recursive: true });
}

class MessageStore {
  constructor() {
    // 메모리 캐시: deskId → messages[]
    this.cache = new Map();
    // 저장 필요 표시: deskId Set
    this.dirty = new Set();
    // Debounce 타이머: deskId → timer
    this.saveTimers = new Map();
  }

  /**
   * 메시지 파일 경로
   */
  getFilePath(deskId) {
    return path.join(MESSAGES_DIR, `${deskId}.json`);
  }

  /**
   * 데스크의 메시지 로드 (페이징 지원)
   * @param {string} deskId
   * @param {object} options - { limit, offset }
   */
  load(deskId, options = {}) {
    const { limit = MAX_MESSAGES_PER_DESK, offset = 0 } = options;

    // 캐시에 있으면 캐시에서
    if (this.cache.has(deskId)) {
      const messages = this.cache.get(deskId);
      if (offset === 0 && limit >= messages.length) {
        return messages;
      }
      const start = Math.max(0, messages.length - limit - offset);
      const end = messages.length - offset;
      return messages.slice(start, end);
    }

    // 파일에서 로드
    try {
      const filePath = this.getFilePath(deskId);
      if (fs.existsSync(filePath)) {
        const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
        const messages = data.messages || [];
        // 캐시에 저장
        this.cache.set(deskId, messages);

        if (offset === 0 && limit >= messages.length) {
          return messages;
        }
        const start = Math.max(0, messages.length - limit - offset);
        const end = messages.length - offset;
        return messages.slice(start, end);
      }
    } catch (err) {
      console.error(`[MessageStore] Failed to load ${deskId}:`, err.message);
    }

    // 빈 배열로 캐시 초기화
    this.cache.set(deskId, []);
    return [];
  }

  /**
   * 캐시 확보 (없으면 파일에서 로드)
   */
  ensureCache(deskId) {
    if (!this.cache.has(deskId)) {
      this.load(deskId);
    }
    return this.cache.get(deskId);
  }

  /**
   * 즉시 파일에 저장
   */
  saveNow(deskId) {
    if (!this.cache.has(deskId)) return;

    // 기존 타이머 취소
    if (this.saveTimers.has(deskId)) {
      clearTimeout(this.saveTimers.get(deskId));
      this.saveTimers.delete(deskId);
    }

    try {
      const messages = this.cache.get(deskId);
      const filePath = this.getFilePath(deskId);
      // 최대 개수 제한
      const trimmed = messages.slice(-MAX_MESSAGES_PER_DESK);
      if (trimmed.length < messages.length) {
        this.cache.set(deskId, trimmed);
      }
      fs.writeFileSync(filePath, JSON.stringify({
        deskId,
        messages: trimmed,
        updatedAt: Date.now()
      }, null, 2));
      this.dirty.delete(deskId);
    } catch (err) {
      console.error(`[MessageStore] Failed to save ${deskId}:`, err.message);
    }
  }

  /**
   * Debounced 저장 예약
   */
  scheduleSave(deskId) {
    this.dirty.add(deskId);

    // 기존 타이머가 있으면 취소
    if (this.saveTimers.has(deskId)) {
      clearTimeout(this.saveTimers.get(deskId));
    }

    // 새 타이머 설정
    const timer = setTimeout(() => {
      this.saveTimers.delete(deskId);
      if (this.dirty.has(deskId)) {
        this.saveNow(deskId);
      }
    }, SAVE_DEBOUNCE_MS);

    this.saveTimers.set(deskId, timer);
  }

  /**
   * 메시지 추가 (자동 저장)
   */
  addMessage(deskId, message) {
    const messages = this.ensureCache(deskId);
    messages.push({
      ...message,
      timestamp: message.timestamp || Date.now()
    });
    this.scheduleSave(deskId);
    return messages;
  }

  /**
   * 사용자 메시지 추가
   */
  addUserMessage(deskId, content) {
    return this.addMessage(deskId, {
      role: 'user',
      type: 'text',
      content
    });
  }

  /**
   * 어시스턴트 텍스트 추가
   */
  addAssistantText(deskId, content) {
    return this.addMessage(deskId, {
      role: 'assistant',
      type: 'text',
      content
    });
  }

  /**
   * 도구 시작 추가
   */
  addToolStart(deskId, toolName, toolInput) {
    return this.addMessage(deskId, {
      role: 'assistant',
      type: 'tool_start',
      toolName,
      toolInput
    });
  }

  /**
   * 도구 완료 업데이트
   */
  updateToolComplete(deskId, toolName, success, result, error) {
    const messages = this.ensureCache(deskId);
    // 가장 최근의 해당 도구 찾기
    for (let i = messages.length - 1; i >= 0; i--) {
      const msg = messages[i];
      if (msg.type === 'tool_start' && msg.toolName === toolName) {
        messages[i] = {
          ...msg,
          type: 'tool_complete',
          success,
          output: result,
          error
        };
        break;
      }
    }
    this.scheduleSave(deskId);
    return messages;
  }

  /**
   * 에러 추가
   */
  addError(deskId, errorMessage) {
    return this.addMessage(deskId, {
      role: 'system',
      type: 'error',
      content: errorMessage
    });
  }

  /**
   * 결과 정보 추가
   */
  addResult(deskId, resultData) {
    return this.addMessage(deskId, {
      role: 'system',
      type: 'result',
      ...resultData
    });
  }

  /**
   * 데스크 메시지 초기화
   */
  clear(deskId) {
    // 타이머 취소
    if (this.saveTimers.has(deskId)) {
      clearTimeout(this.saveTimers.get(deskId));
      this.saveTimers.delete(deskId);
    }

    // 캐시 제거
    this.cache.delete(deskId);
    this.dirty.delete(deskId);

    // 파일 삭제
    try {
      const filePath = this.getFilePath(deskId);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
      console.log(`[MessageStore] Cleared ${deskId}`);
    } catch (err) {
      console.error(`[MessageStore] Failed to clear ${deskId}:`, err.message);
    }
  }

  /**
   * 데스크 삭제
   */
  delete(deskId) {
    this.clear(deskId);
  }

  /**
   * 캐시 해제 (저장 후 메모리에서 제거)
   * 시청자가 없는 데스크에 사용
   */
  unloadCache(deskId) {
    if (this.dirty.has(deskId)) {
      this.saveNow(deskId);
    }
    this.cache.delete(deskId);
  }

  /**
   * 모든 dirty 데스크 즉시 저장 (종료 시)
   */
  saveAll() {
    for (const deskId of this.dirty) {
      this.saveNow(deskId);
    }
  }

  /**
   * 메시지 개수 조회 (캐시에서)
   */
  getCount(deskId) {
    if (this.cache.has(deskId)) {
      return this.cache.get(deskId).length;
    }
    // 파일에서 확인
    try {
      const filePath = this.getFilePath(deskId);
      if (fs.existsSync(filePath)) {
        const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
        return (data.messages || []).length;
      }
    } catch (err) {
      // ignore
    }
    return 0;
  }
}

// 싱글톤 인스턴스
const messageStore = new MessageStore();

// 프로세스 종료 시 저장
process.on('beforeExit', () => {
  messageStore.saveAll();
});

process.on('SIGINT', () => {
  messageStore.saveAll();
});

export default messageStore;
