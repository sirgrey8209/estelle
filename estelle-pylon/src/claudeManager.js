/**
 * Claude Manager - Claude Agent SDK 기반
 * SlackClaudeBot의 claude-sdk.ts 구조를 참고하여 모든 이벤트 지원
 *
 * 이벤트 목록:
 * - init: 세션 초기화 { session_id, model, tools }
 * - stateUpdate: 상태 변경 { state, partialText }
 * - textComplete: 텍스트 완료 { text }
 * - toolInfo: 도구 시작 { toolName, input }
 * - toolComplete: 도구 완료 { toolName, success, result, error }
 * - askQuestion: 사용자 질문 { questions, toolUseId }
 * - permission_request: 권한 요청 { toolName, toolInput, toolUseId }
 * - result: 처리 완료 { subtype, duration_ms, total_cost_usd, num_turns, usage }
 * - error: 에러 { error }
 * - state: 상태 변경 (idle/working/permission)
 */

import { query } from '@anthropic-ai/claude-agent-sdk';
import fs from 'fs';
import path from 'path';
import deskStore from './deskStore.js';

const LOG_DIR = path.join(process.cwd(), 'logs');

/**
 * Claude Manager 클래스
 */
class ClaudeManager {
  constructor(onEvent) {
    this.onEvent = onEvent;
    this.sessions = new Map();  // deskId -> { query, abortController, sessionId, state, partialText }
    this.pendingPermissions = new Map();
    this.pendingQuestions = new Map();
    // Desktop 재연결 시 전송할 pending 이벤트 저장
    this.pendingEvents = new Map();  // deskId -> { type, ... }
    this.logStream = null;

    // 로그 디렉토리 생성
    if (!fs.existsSync(LOG_DIR)) {
      fs.mkdirSync(LOG_DIR, { recursive: true });
    }

    const logFile = path.join(LOG_DIR, `sdk-${this.getDateString()}.jsonl`);
    this.logStream = fs.createWriteStream(logFile, { flags: 'a' });
    console.log(`[ClaudeManager] Logging to: ${logFile}`);
  }

  getDateString() {
    return new Date().toISOString().split('T')[0];
  }

  log(deskId, direction, data) {
    const entry = {
      timestamp: Date.now(),
      deskId,
      direction,
      data
    };

    if (this.logStream) {
      this.logStream.write(JSON.stringify(entry) + '\n');
    }
  }

  emitEvent(deskId, event) {
    this.log(deskId, 'output', event);
    if (this.onEvent) {
      this.onEvent(deskId, event);
    }
  }

  /** 자동 허용 도구 */
  autoAllowTools = new Set([
    'Read', 'Glob', 'Grep', 'WebSearch', 'WebFetch', 'TodoWrite',
  ]);

  /** 자동 거부 패턴 */
  autoDenyPatterns = [
    { toolName: 'Edit', pattern: /\.(env|secret|credentials|password)/i, reason: 'Protected file' },
    { toolName: 'Write', pattern: /\.(env|secret|credentials|password)/i, reason: 'Protected file' },
    { toolName: 'Bash', pattern: /rm\s+-rf\s+\/|format\s+|del\s+\/f\s+\/s|shutdown|reboot|mkfs/i, reason: 'Dangerous command' },
  ];

  /**
   * Claude에게 메시지 전송
   */
  async sendMessage(deskId, message) {
    const desk = deskStore.getDesk(deskId);
    if (!desk) {
      this.emitEvent(deskId, { type: 'error', error: `Desk not found: ${deskId}` });
      return;
    }

    // 이미 실행 중이면 중지
    if (this.sessions.has(deskId)) {
      console.log(`[ClaudeManager] Already running, stopping first`);
      this.stop(deskId);
      await new Promise(resolve => setTimeout(resolve, 200));
    }

    this.log(deskId, 'input', { type: 'message', message });

    deskStore.updateDeskStatus(deskId, 'working');
    this.emitEvent(deskId, { type: 'state', state: 'working' });

    try {
      await this.runQuery(deskId, desk, message);
    } catch (err) {
      console.error(`[ClaudeManager] Error:`, err.message);
      this.emitEvent(deskId, { type: 'error', error: err.message });
    } finally {
      this.sessions.delete(deskId);
      deskStore.updateDeskStatus(deskId, 'idle');
      this.emitEvent(deskId, { type: 'state', state: 'idle' });
    }
  }

  /**
   * SDK query 실행
   */
  async runQuery(deskId, desk, message) {
    const abortController = new AbortController();

    const queryOptions = {
      cwd: desk.workingDir,
      abortController,
      includePartialMessages: true,
      canUseTool: async (toolName, input) => {
        return this.handlePermission(deskId, toolName, input);
      }
    };

    if (desk.claudeSessionId) {
      queryOptions.resume = desk.claudeSessionId;
      console.log(`[ClaudeManager] Resuming session: ${desk.claudeSessionId}`);
    }

    console.log(`[ClaudeManager] Running query in: ${desk.workingDir}`);

    const q = query({ prompt: message, options: queryOptions });

    // 세션 상태 초기화
    const session = {
      query: q,
      abortController,
      sessionId: null,
      state: { type: 'thinking' },
      partialText: '',
      startTime: Date.now(),
      pendingTools: new Map(),  // toolUseId -> toolName
      usage: {
        inputTokens: 0,
        outputTokens: 0,
        cacheReadInputTokens: 0,
        cacheCreationInputTokens: 0
      }
    };
    this.sessions.set(deskId, session);

    // 초기 thinking 상태 전송
    this.emitEvent(deskId, {
      type: 'stateUpdate',
      state: session.state,
      partialText: ''
    });

    for await (const msg of q) {
      this.handleMessage(deskId, session, msg);
    }
  }

  /**
   * SDK 메시지 처리
   */
  handleMessage(deskId, session, msg) {
    // 디버그 로그
    if (msg.type === 'stream_event') {
      console.log(`[ClaudeManager] STREAM: ${msg.event?.type}`);
    } else {
      console.log(`[ClaudeManager] MSG: ${msg.type}/${msg.subtype || '-'}`);
    }

    switch (msg.type) {
      case 'system':
        if (msg.subtype === 'init') {
          session.sessionId = msg.session_id;
          console.log(`[ClaudeManager] Session: ${msg.session_id}, Model: ${msg.model}`);

          deskStore.updateClaudeSessionId(deskId, msg.session_id);

          this.emitEvent(deskId, {
            type: 'init',
            session_id: msg.session_id,
            model: msg.model,
            tools: msg.tools
          });
        }
        break;

      case 'assistant':
        // 어시스턴트 메시지 완성
        for (const block of msg.message.content) {
          if (block.type === 'text') {
            console.log(`[ClaudeManager] Text complete: ${block.text.length} chars`);
            this.emitEvent(deskId, {
              type: 'textComplete',
              text: block.text
            });
            session.partialText = '';
          } else if (block.type === 'tool_use') {
            console.log(`[ClaudeManager] Tool use: ${block.name} (id: ${block.id})`);
            session.pendingTools.set(block.id, block.name);

            if (block.name === 'AskUserQuestion') {
              // 질문 이벤트
              const askEvent = {
                type: 'askQuestion',
                questions: block.input.questions,
                toolUseId: block.id
              };
              this.pendingEvents.set(deskId, askEvent);
              this.emitEvent(deskId, askEvent);
            } else {
              // 도구 정보 이벤트
              this.emitEvent(deskId, {
                type: 'toolInfo',
                toolName: block.name,
                input: block.input
              });
            }
          }
        }
        break;

      case 'user':
        // 도구 실행 결과
        const content = msg.message?.content;
        if (Array.isArray(content)) {
          for (const block of content) {
            if (block.type === 'tool_result' && block.tool_use_id) {
              const toolUseId = block.tool_use_id;
              const toolName = session.pendingTools.get(toolUseId) || 'Unknown';
              const isError = block.is_error === true;

              let resultContent = '';
              if (typeof block.content === 'string') {
                resultContent = block.content;
              } else if (Array.isArray(block.content)) {
                resultContent = block.content
                  .filter(c => c.type === 'text')
                  .map(c => c.text)
                  .join('\n');
              }

              console.log(`[ClaudeManager] Tool result: ${toolName} - ${isError ? 'ERROR' : 'SUCCESS'}`);
              session.pendingTools.delete(toolUseId);

              this.emitEvent(deskId, {
                type: 'toolComplete',
                toolName,
                success: !isError,
                result: resultContent.substring(0, 1000),
                error: isError ? resultContent.substring(0, 200) : undefined
              });
            }
          }
        }
        break;

      case 'stream_event':
        const event = msg.event;

        // 메시지 시작 - 토큰 정보 추출
        if (event.type === 'message_start' && event.message?.usage) {
          session.usage.inputTokens += event.message.usage.input_tokens || 0;
          if (event.message.usage.cache_read_input_tokens) {
            session.usage.cacheReadInputTokens += event.message.usage.cache_read_input_tokens;
          }
          if (event.message.usage.cache_creation_input_tokens) {
            session.usage.cacheCreationInputTokens += event.message.usage.cache_creation_input_tokens;
          }
        }

        // 콘텐츠 블록 시작
        if (event.type === 'content_block_start') {
          const block = event.content_block;
          if (block?.type === 'text') {
            session.partialText = '';
            session.state = { type: 'responding' };
            this.emitEvent(deskId, {
              type: 'stateUpdate',
              state: session.state,
              partialText: ''
            });
          } else if (block?.type === 'tool_use' && block.name) {
            console.log(`[ClaudeManager] Tool start: ${block.name}`);
            session.partialText = '';
            session.state = { type: 'tool', toolName: block.name };
            session.pendingTools.set(block.id, block.name);
            this.emitEvent(deskId, {
              type: 'stateUpdate',
              state: session.state,
              partialText: ''
            });
          }
        }

        // 텍스트 델타
        if (event.type === 'content_block_delta') {
          const delta = event.delta;
          if (delta?.type === 'text_delta' && delta.text) {
            session.partialText += delta.text;
            // 스트리밍 텍스트 전송
            this.emitEvent(deskId, { type: 'text', content: delta.text });
          }
        }

        // 블록 종료 - thinking으로 전환
        if (event.type === 'content_block_stop') {
          session.state = { type: 'thinking' };
          this.emitEvent(deskId, {
            type: 'stateUpdate',
            state: session.state,
            partialText: session.partialText
          });
        }

        // 메시지 델타 - 출력 토큰 정보
        if (event.type === 'message_delta' && event.usage) {
          session.usage.outputTokens += event.usage.output_tokens || 0;
        }
        break;

      case 'tool_progress':
        // 도구 진행 상황
        console.log(`[ClaudeManager] Tool progress: ${msg.tool_name} (${msg.elapsed_time_seconds}s)`);
        if (msg.tool_name) {
          session.state = { type: 'tool', toolName: msg.tool_name };
          this.emitEvent(deskId, {
            type: 'stateUpdate',
            state: session.state,
            partialText: ''
          });
        }
        break;

      case 'result':
        const duration = Date.now() - session.startTime;
        console.log(`[ClaudeManager] Result: ${msg.subtype}, cost: $${msg.total_cost_usd?.toFixed(4)}, time: ${(duration/1000).toFixed(1)}s`);

        // 토큰 사용량 추출 (result 메시지에서)
        if (msg.usage) {
          session.usage.inputTokens = msg.usage.input_tokens || session.usage.inputTokens;
          session.usage.outputTokens = msg.usage.output_tokens || session.usage.outputTokens;
          session.usage.cacheReadInputTokens = msg.usage.cache_read_input_tokens || session.usage.cacheReadInputTokens;
          session.usage.cacheCreationInputTokens = msg.usage.cache_creation_input_tokens || session.usage.cacheCreationInputTokens;
        }

        this.emitEvent(deskId, {
          type: 'result',
          subtype: msg.subtype,
          duration_ms: duration,
          total_cost_usd: msg.total_cost_usd,
          num_turns: msg.num_turns,
          usage: session.usage
        });
        break;
    }
  }

  /**
   * 권한 핸들러
   */
  async handlePermission(deskId, toolName, input) {
    // 자동 허용
    if (this.autoAllowTools.has(toolName)) {
      console.log(`[ClaudeManager] Auto-allow: ${toolName}`);
      return { behavior: 'allow', updatedInput: input };
    }

    // 자동 거부 패턴 체크
    for (const { toolName: tn, pattern, reason } of this.autoDenyPatterns) {
      if (toolName === tn) {
        const value = toolName === 'Bash'
          ? (input.command || '')
          : (input.file_path || '');

        if (pattern.test(value)) {
          console.log(`[ClaudeManager] Auto-deny: ${toolName} - ${reason}`);
          return { behavior: 'deny', message: reason };
        }
      }
    }

    // 사용자에게 권한 요청
    const toolUseId = `perm_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    console.log(`[ClaudeManager] Requesting permission: ${toolName} (${toolUseId})`);

    // AskUserQuestion 특별 처리
    if (toolName === 'AskUserQuestion') {
      return new Promise((resolve) => {
        this.pendingQuestions.set(toolUseId, { resolve, input });
        // askQuestion 이벤트는 assistant 메시지에서 이미 emit됨
        console.log(`[ClaudeManager] AskUserQuestion stored, waiting for answer`);
      });
    }

    return new Promise((resolve) => {
      this.pendingPermissions.set(toolUseId, { resolve, toolName, input, deskId });

      const permEvent = {
        type: 'permission_request',
        toolName,
        toolInput: input,
        toolUseId
      };
      this.pendingEvents.set(deskId, permEvent);
      deskStore.updateDeskStatus(deskId, 'permission');
      this.emitEvent(deskId, permEvent);
    });
  }

  /**
   * 실행 중지
   */
  stop(deskId) {
    const session = this.sessions.get(deskId);
    if (session?.abortController) {
      console.log(`[ClaudeManager] Stopping desk: ${deskId}`);
      session.abortController.abort();
      this.sessions.delete(deskId);
      deskStore.updateDeskStatus(deskId, 'idle');
      this.emitEvent(deskId, { type: 'state', state: 'idle' });
    }

    // 대기 중인 권한 요청 모두 거부
    for (const [id, pending] of this.pendingPermissions) {
      pending.resolve({ behavior: 'deny', message: 'Stopped' });
    }
    this.pendingPermissions.clear();

    for (const [id, pending] of this.pendingQuestions) {
      pending.resolve({ behavior: 'deny', message: 'Stopped' });
    }
    this.pendingQuestions.clear();
  }

  /**
   * 새 세션 시작
   */
  newSession(deskId) {
    this.stop(deskId);
    deskStore.updateClaudeSessionId(deskId, null);
    this.emitEvent(deskId, { type: 'state', state: 'idle' });
    console.log(`[ClaudeManager] New session for desk: ${deskId}`);
  }

  /**
   * 세션 재개 - 저장된 sessionId로 연결만 복구
   */
  async resumeSession(deskId) {
    const desk = deskStore.getDesk(deskId);
    if (!desk?.claudeSessionId) {
      console.log(`[ClaudeManager] No session to resume for desk: ${deskId}`);
      this.emitEvent(deskId, { type: 'error', error: 'No session to resume' });
      return;
    }

    console.log(`[ClaudeManager] Resuming session for desk: ${deskId}, sessionId: ${desk.claudeSessionId}`);

    // 빈 메시지 없이 세션만 활성화 (다음 메시지에서 resume 사용)
    // 실제로는 query를 보내지 않고, 다음 sendMessage에서 resume 옵션이 적용됨
    this.emitEvent(deskId, {
      type: 'init',
      session_id: desk.claudeSessionId,
      message: 'Session ready to resume'
    });
    this.emitEvent(deskId, { type: 'state', state: 'idle' });
  }

  /**
   * 권한 응답
   */
  respondPermission(deskId, toolUseId, decision) {
    const pending = this.pendingPermissions.get(toolUseId);
    if (pending) {
      console.log(`[ClaudeManager] Permission ${decision} for ${pending.toolName}`);
      this.pendingPermissions.delete(toolUseId);
      this.pendingEvents.delete(deskId);
      this.log(deskId, 'input', { type: 'permission_response', toolUseId, decision });

      if (decision === 'allow' || decision === 'allowAll') {
        pending.resolve({ behavior: 'allow', updatedInput: pending.input });
      } else {
        pending.resolve({ behavior: 'deny', message: 'User denied' });
      }

      deskStore.updateDeskStatus(deskId, 'working');
    }
  }

  /**
   * 질문 응답
   */
  respondQuestion(deskId, toolUseId, answer) {
    // 먼저 toolUseId로 찾기
    let pending = this.pendingQuestions.get(toolUseId);
    let foundId = toolUseId;

    // 못 찾으면 첫 번째 pending question 사용 (ID 불일치 대응)
    if (!pending && this.pendingQuestions.size > 0) {
      for (const [id, p] of this.pendingQuestions) {
        pending = p;
        foundId = id;
        break;
      }
    }

    if (pending) {
      console.log(`[ClaudeManager] Question answer: ${answer} (id: ${foundId})`);
      this.pendingQuestions.delete(foundId);
      this.pendingEvents.delete(deskId);
      this.log(deskId, 'input', { type: 'question_response', toolUseId: foundId, answer });

      const updatedInput = {
        ...pending.input,
        answers: { '0': answer }
      };
      pending.resolve({ behavior: 'allow', updatedInput });
    }
  }

  /**
   * 특정 데스크의 pending 이벤트 가져오기
   */
  getPendingEvent(deskId) {
    return this.pendingEvents.get(deskId) || null;
  }

  /**
   * 모든 pending 이벤트 가져오기
   */
  getAllPendingEvents() {
    const result = [];
    for (const [deskId, event] of this.pendingEvents) {
      result.push({ deskId, event });
    }
    return result;
  }

  /**
   * 특정 데스크에 활성 세션이 있는지 확인
   */
  hasActiveSession(deskId) {
    return this.sessions.has(deskId);
  }

  /**
   * 모든 활성 세션 ID 목록
   */
  getActiveSessionDeskIds() {
    return Array.from(this.sessions.keys());
  }

  /**
   * 정리
   */
  cleanup() {
    this.sessions.forEach((session, deskId) => {
      this.stop(deskId);
    });

    if (this.logStream) {
      this.logStream.end();
    }
  }
}

export default ClaudeManager;
