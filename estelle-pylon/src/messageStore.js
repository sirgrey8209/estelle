/**
 * Message Store - 세션별 메시지 히스토리 저장
 * 메모리 캐시 + Debounced 파일 저장 + 페이징 지원
 */

import fs from 'fs';
import path from 'path';

const MESSAGES_DIR = path.join(process.cwd(), 'messages');
const MAX_MESSAGES_PER_SESSION = 200;
const SAVE_DEBOUNCE_MS = 2000; // 2초 debounce
const MAX_OUTPUT_LENGTH = 500;
const MAX_INPUT_LENGTH = 300;

/**
 * toolInput 요약 (히스토리 저장용)
 * 파일 경로, 명령어 첫 줄 등 핵심 정보만 유지
 */
function summarizeToolInput(toolName, input) {
  if (!input) return input;

  // 파일 관련 도구는 경로만
  if (['Read', 'Edit', 'Write', 'NotebookEdit'].includes(toolName)) {
    const result = {};
    if (input.file_path) result.file_path = input.file_path;
    if (input.notebook_path) result.notebook_path = input.notebook_path;
    return result;
  }

  // Bash는 description + command 첫 줄만
  if (toolName === 'Bash') {
    const result = {};
    if (input.description) result.description = input.description;
    if (input.command) {
      const firstLine = input.command.split('\n')[0];
      result.command = firstLine.length > MAX_INPUT_LENGTH
        ? firstLine.slice(0, MAX_INPUT_LENGTH) + '...'
        : firstLine;
    }
    return result;
  }

  // Glob, Grep는 pattern과 path
  if (['Glob', 'Grep'].includes(toolName)) {
    const result = {};
    if (input.pattern) result.pattern = input.pattern;
    if (input.path) result.path = input.path;
    return result;
  }

  // 기타는 값이 길면 truncate
  return truncateObjectValues(input, MAX_INPUT_LENGTH);
}

/**
 * 객체의 문자열 값들을 truncate
 */
function truncateObjectValues(obj, maxLength) {
  if (!obj || typeof obj !== 'object') return obj;

  const result = {};
  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === 'string' && value.length > maxLength) {
      result[key] = value.slice(0, maxLength) + '...';
    } else if (typeof value === 'object' && value !== null) {
      result[key] = truncateObjectValues(value, maxLength);
    } else {
      result[key] = value;
    }
  }
  return result;
}

/**
 * output 요약 (히스토리 저장용)
 */
function summarizeOutput(output) {
  if (!output || typeof output !== 'string') return output;
  if (output.length <= MAX_OUTPUT_LENGTH) return output;
  return output.slice(0, MAX_OUTPUT_LENGTH) + `\n... (${output.length} chars total)`;
}

// 디렉토리 생성
if (!fs.existsSync(MESSAGES_DIR)) {
  fs.mkdirSync(MESSAGES_DIR, { recursive: true });
}

class MessageStore {
  constructor() {
    // 메모리 캐시: sessionId → messages[]
    this.cache = new Map();
    // 저장 필요 표시: sessionId Set
    this.dirty = new Set();
    // Debounce 타이머: sessionId → timer
    this.saveTimers = new Map();
  }

  /**
   * 메시지 파일 경로
   */
  getFilePath(sessionId) {
    return path.join(MESSAGES_DIR, `${sessionId}.json`);
  }

  /**
   * 세션의 메시지 로드 (페이징 지원)
   * @param {string} sessionId
   * @param {object} options - { limit, offset }
   */
  load(sessionId, options = {}) {
    const { limit = MAX_MESSAGES_PER_SESSION, offset = 0 } = options;

    // 캐시에 있으면 캐시에서
    if (this.cache.has(sessionId)) {
      const messages = this.cache.get(sessionId);
      if (offset === 0 && limit >= messages.length) {
        return messages;
      }
      const start = Math.max(0, messages.length - limit - offset);
      const end = messages.length - offset;
      return messages.slice(start, end);
    }

    // 파일에서 로드
    try {
      const filePath = this.getFilePath(sessionId);
      if (fs.existsSync(filePath)) {
        const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
        const messages = data.messages || [];
        // 캐시에 저장
        this.cache.set(sessionId, messages);

        if (offset === 0 && limit >= messages.length) {
          return messages;
        }
        const start = Math.max(0, messages.length - limit - offset);
        const end = messages.length - offset;
        return messages.slice(start, end);
      }
    } catch (err) {
      console.error(`[MessageStore] Failed to load ${sessionId}:`, err.message);
    }

    // 빈 배열로 캐시 초기화
    this.cache.set(sessionId, []);
    return [];
  }

  /**
   * 캐시 확보 (없으면 파일에서 로드)
   */
  ensureCache(sessionId) {
    if (!this.cache.has(sessionId)) {
      this.load(sessionId);
    }
    return this.cache.get(sessionId);
  }

  /**
   * 즉시 파일에 저장
   */
  saveNow(sessionId) {
    if (!this.cache.has(sessionId)) return;

    // 기존 타이머 취소
    if (this.saveTimers.has(sessionId)) {
      clearTimeout(this.saveTimers.get(sessionId));
      this.saveTimers.delete(sessionId);
    }

    try {
      const messages = this.cache.get(sessionId);
      const filePath = this.getFilePath(sessionId);
      // 최대 개수 제한
      const trimmed = messages.slice(-MAX_MESSAGES_PER_SESSION);
      if (trimmed.length < messages.length) {
        this.cache.set(sessionId, trimmed);
      }
      fs.writeFileSync(filePath, JSON.stringify({
        sessionId,
        messages: trimmed,
        updatedAt: Date.now()
      }, null, 2));
      this.dirty.delete(sessionId);
    } catch (err) {
      console.error(`[MessageStore] Failed to save ${sessionId}:`, err.message);
    }
  }

  /**
   * Debounced 저장 예약
   */
  scheduleSave(sessionId) {
    this.dirty.add(sessionId);

    // 기존 타이머가 있으면 취소
    if (this.saveTimers.has(sessionId)) {
      clearTimeout(this.saveTimers.get(sessionId));
    }

    // 새 타이머 설정
    const timer = setTimeout(() => {
      this.saveTimers.delete(sessionId);
      if (this.dirty.has(sessionId)) {
        this.saveNow(sessionId);
      }
    }, SAVE_DEBOUNCE_MS);

    this.saveTimers.set(sessionId, timer);
  }

  /**
   * 메시지 추가 (자동 저장)
   */
  addMessage(sessionId, message) {
    const messages = this.ensureCache(sessionId);
    messages.push({
      ...message,
      timestamp: message.timestamp || Date.now()
    });
    this.scheduleSave(sessionId);
    return messages;
  }

  /**
   * 사용자 메시지 추가
   */
  addUserMessage(sessionId, content) {
    return this.addMessage(sessionId, {
      role: 'user',
      type: 'text',
      content
    });
  }

  /**
   * 어시스턴트 텍스트 추가
   */
  addAssistantText(sessionId, content) {
    return this.addMessage(sessionId, {
      role: 'assistant',
      type: 'text',
      content
    });
  }

  /**
   * 도구 시작 추가 (toolInput 요약하여 저장)
   */
  addToolStart(sessionId, toolName, toolInput) {
    return this.addMessage(sessionId, {
      role: 'assistant',
      type: 'tool_start',
      toolName,
      toolInput: summarizeToolInput(toolName, toolInput)
    });
  }

  /**
   * 도구 완료 업데이트 (output 요약하여 저장)
   */
  updateToolComplete(sessionId, toolName, success, result, error) {
    const messages = this.ensureCache(sessionId);
    // 가장 최근의 해당 도구 찾기
    for (let i = messages.length - 1; i >= 0; i--) {
      const msg = messages[i];
      if (msg.type === 'tool_start' && msg.toolName === toolName) {
        messages[i] = {
          ...msg,
          type: 'tool_complete',
          success,
          output: summarizeOutput(result),
          error: summarizeOutput(error)
        };
        break;
      }
    }
    this.scheduleSave(sessionId);
    return messages;
  }

  /**
   * 에러 추가
   */
  addError(sessionId, errorMessage) {
    return this.addMessage(sessionId, {
      role: 'system',
      type: 'error',
      content: errorMessage
    });
  }

  /**
   * 결과 정보 추가
   */
  addResult(sessionId, resultData) {
    return this.addMessage(sessionId, {
      role: 'system',
      type: 'result',
      ...resultData
    });
  }

  /**
   * 세션 메시지 초기화
   */
  clear(sessionId) {
    // 타이머 취소
    if (this.saveTimers.has(sessionId)) {
      clearTimeout(this.saveTimers.get(sessionId));
      this.saveTimers.delete(sessionId);
    }

    // 캐시 제거
    this.cache.delete(sessionId);
    this.dirty.delete(sessionId);

    // 파일 삭제
    try {
      const filePath = this.getFilePath(sessionId);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
      console.log(`[MessageStore] Cleared ${sessionId}`);
    } catch (err) {
      console.error(`[MessageStore] Failed to clear ${sessionId}:`, err.message);
    }
  }

  /**
   * 세션 삭제
   */
  delete(sessionId) {
    this.clear(sessionId);
  }

  /**
   * 캐시 해제 (저장 후 메모리에서 제거)
   * 시청자가 없는 세션에 사용
   */
  unloadCache(sessionId) {
    if (this.dirty.has(sessionId)) {
      this.saveNow(sessionId);
    }
    this.cache.delete(sessionId);
  }

  /**
   * 모든 dirty 세션 즉시 저장 (종료 시)
   */
  saveAll() {
    for (const sessionId of this.dirty) {
      this.saveNow(sessionId);
    }
  }

  /**
   * 메시지 개수 조회 (캐시에서)
   */
  getCount(sessionId) {
    if (this.cache.has(sessionId)) {
      return this.cache.get(sessionId).length;
    }
    // 파일에서 확인
    try {
      const filePath = this.getFilePath(sessionId);
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
