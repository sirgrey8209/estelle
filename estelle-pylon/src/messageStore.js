/**
 * Message Store - 데스크별 메시지 히스토리 저장
 */

import fs from 'fs';
import path from 'path';

const MESSAGES_DIR = path.join(process.cwd(), 'messages');
const MAX_MESSAGES_PER_DESK = 100;

// 디렉토리 생성
if (!fs.existsSync(MESSAGES_DIR)) {
  fs.mkdirSync(MESSAGES_DIR, { recursive: true });
}

const messageStore = {
  /**
   * 메시지 파일 경로
   */
  getFilePath(deskId) {
    return path.join(MESSAGES_DIR, `${deskId}.json`);
  },

  /**
   * 데스크의 메시지 로드
   */
  load(deskId) {
    try {
      const filePath = this.getFilePath(deskId);
      if (fs.existsSync(filePath)) {
        const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
        return data.messages || [];
      }
    } catch (err) {
      console.error(`[MessageStore] Failed to load ${deskId}:`, err.message);
    }
    return [];
  },

  /**
   * 데스크의 메시지 저장
   */
  save(deskId, messages) {
    try {
      const filePath = this.getFilePath(deskId);
      // 최대 개수 제한
      const trimmed = messages.slice(-MAX_MESSAGES_PER_DESK);
      fs.writeFileSync(filePath, JSON.stringify({
        deskId,
        messages: trimmed,
        updatedAt: Date.now()
      }, null, 2));
    } catch (err) {
      console.error(`[MessageStore] Failed to save ${deskId}:`, err.message);
    }
  },

  /**
   * 메시지 추가 (자동 저장)
   */
  addMessage(deskId, message) {
    const messages = this.load(deskId);
    messages.push({
      ...message,
      timestamp: message.timestamp || Date.now()
    });
    this.save(deskId, messages);
    return messages;
  },

  /**
   * 사용자 메시지 추가
   */
  addUserMessage(deskId, content) {
    return this.addMessage(deskId, {
      role: 'user',
      type: 'text',
      content
    });
  },

  /**
   * 어시스턴트 텍스트 추가
   */
  addAssistantText(deskId, content) {
    return this.addMessage(deskId, {
      role: 'assistant',
      type: 'text',
      content
    });
  },

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
  },

  /**
   * 도구 완료 업데이트
   */
  updateToolComplete(deskId, toolName, success, result, error) {
    const messages = this.load(deskId);
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
    this.save(deskId, messages);
    return messages;
  },

  /**
   * 에러 추가
   */
  addError(deskId, errorMessage) {
    return this.addMessage(deskId, {
      role: 'system',
      type: 'error',
      content: errorMessage
    });
  },

  /**
   * 결과 정보 추가
   */
  addResult(deskId, resultData) {
    return this.addMessage(deskId, {
      role: 'system',
      type: 'result',
      ...resultData
    });
  },

  /**
   * 데스크 메시지 초기화
   */
  clear(deskId) {
    try {
      const filePath = this.getFilePath(deskId);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
      console.log(`[MessageStore] Cleared ${deskId}`);
    } catch (err) {
      console.error(`[MessageStore] Failed to clear ${deskId}:`, err.message);
    }
  },

  /**
   * 데스크 삭제
   */
  delete(deskId) {
    this.clear(deskId);
  }
};

export default messageStore;
