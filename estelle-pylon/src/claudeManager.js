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

const LOG_DIR = path.join(process.cwd(), 'logs');

// 대화별 퍼미션 모드 (conversationId -> mode)
const permissionModes = new Map();

/**
 * Claude Manager 클래스
 */
class ClaudeManager {
  constructor(onEvent) {
    this.onEvent = onEvent;
    this.sessions = new Map();  // sessionId -> { query, abortController, claudeSessionId, state, partialText }
    this.pendingPermissions = new Map();
    this.pendingQuestions = new Map();
    // 재연결 시 전송할 pending 이벤트 저장
    this.pendingEvents = new Map();  // sessionId -> { type, ... }
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

  log(sessionId, direction, data) {
    const entry = {
      timestamp: Date.now(),
      sessionId,
      direction,
      data
    };

    if (this.logStream) {
      this.logStream.write(JSON.stringify(entry) + '\n');
    }
  }

  emitEvent(sessionId, event) {
    this.log(sessionId, 'output', event);
    if (this.onEvent) {
      this.onEvent(sessionId, event);
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
   * 퍼미션 모드 설정 (대화별)
   */
  static setPermissionMode(conversationId, mode) {
    permissionModes.set(conversationId, mode);
    console.log(`[ClaudeManager] Permission mode for ${conversationId}: ${mode}`);
  }

  static getPermissionMode(conversationId) {
    return permissionModes.get(conversationId) || 'default';
  }

  /**
   * Claude에게 메시지 전송
   * @param {string} sessionId - conversationId
   * @param {string} message - 사용자 메시지
   * @param {Object} options - 옵션 { workingDir, claudeSessionId }
   */
  async sendMessage(sessionId, message, options = {}) {
    const { workingDir, claudeSessionId } = options;

    if (!workingDir) {
      this.emitEvent(sessionId, { type: 'error', error: `Working directory not found for: ${sessionId}` });
      return;
    }

    // 이미 실행 중이면 중지
    if (this.sessions.has(sessionId)) {
      console.log(`[ClaudeManager] Already running, stopping first`);
      this.stop(sessionId);
      await new Promise(resolve => setTimeout(resolve, 200));
    }

    this.log(sessionId, 'input', { type: 'message', message });
    this.emitEvent(sessionId, { type: 'state', state: 'working' });

    try {
      await this.runQuery(sessionId, { workingDir, claudeSessionId }, message);
    } catch (err) {
      console.error(`[ClaudeManager] Error:`, err.message);
      this.emitEvent(sessionId, { type: 'error', error: err.message });
    } finally {
      this.sessions.delete(sessionId);
      this.emitEvent(sessionId, { type: 'state', state: 'idle' });
    }
  }

  /**
   * 워크스페이스의 .mcp.json 파일 읽기
   * @param {string} workingDir - 워크스페이스 디렉토리
   * @returns {Object|null} MCP 서버 설정
   */
  loadMcpConfig(workingDir) {
    const mcpConfigPath = path.join(workingDir, '.mcp.json');

    try {
      if (fs.existsSync(mcpConfigPath)) {
        const content = fs.readFileSync(mcpConfigPath, 'utf-8');
        const config = JSON.parse(content);

        if (config.mcpServers && typeof config.mcpServers === 'object') {
          // cwd가 상대경로면 workingDir 기준으로 변환
          const servers = {};
          for (const [name, serverConfig] of Object.entries(config.mcpServers)) {
            servers[name] = {
              ...serverConfig,
              cwd: serverConfig.cwd || workingDir
            };
          }
          console.log(`[ClaudeManager] Loaded MCP config: ${Object.keys(servers).join(', ')}`);
          return servers;
        }
      }
    } catch (err) {
      console.error(`[ClaudeManager] Failed to load .mcp.json: ${err.message}`);
    }

    return null;
  }

  /**
   * SDK query 실행
   * @param {string} sessionId - conversationId
   * @param {Object} sessionInfo - { workingDir, claudeSessionId }
   * @param {string} message - 사용자 메시지
   */
  async runQuery(sessionId, sessionInfo, message) {
    const abortController = new AbortController();

    const queryOptions = {
      cwd: sessionInfo.workingDir,
      abortController,
      includePartialMessages: true,
      allowedTools: ['Skill'],  // Skills 자동 로드 활성화
      canUseTool: async (toolName, input) => {
        return this.handlePermission(sessionId, toolName, input);
      }
    };

    // MCP 서버 설정 로드
    const mcpServers = this.loadMcpConfig(sessionInfo.workingDir);
    if (mcpServers) {
      queryOptions.mcpServers = mcpServers;
    }

    if (sessionInfo.claudeSessionId) {
      queryOptions.resume = sessionInfo.claudeSessionId;
      console.log(`[ClaudeManager] Resuming session: ${sessionInfo.claudeSessionId}`);
    }

    console.log(`[ClaudeManager] Running query in: ${sessionInfo.workingDir}`);

    const q = query({ prompt: message, options: queryOptions });

    // 세션 상태 초기화
    const session = {
      query: q,
      abortController,
      claudeSessionId: null,
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
    this.sessions.set(sessionId, session);

    // 초기 thinking 상태 전송
    this.emitEvent(sessionId, {
      type: 'stateUpdate',
      state: session.state,
      partialText: ''
    });

    for await (const msg of q) {
      this.handleMessage(sessionId, session, msg);
    }
  }

  /**
   * SDK 메시지 처리
   */
  handleMessage(sessionId, session, msg) {
    // 디버그 로그
    if (msg.type === 'stream_event') {
      console.log(`[ClaudeManager] STREAM: ${msg.event?.type}`);
    } else {
      console.log(`[ClaudeManager] MSG: ${msg.type}/${msg.subtype || '-'}`);
    }

    switch (msg.type) {
      case 'system':
        if (msg.subtype === 'init') {
          session.claudeSessionId = msg.session_id;
          console.log(`[ClaudeManager] Session: ${msg.session_id}, Model: ${msg.model}`);

          this.emitEvent(sessionId, {
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
            this.emitEvent(sessionId, {
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
              this.pendingEvents.set(sessionId, askEvent);
              this.emitEvent(sessionId, askEvent);
            } else {
              // 도구 정보 이벤트
              this.emitEvent(sessionId, {
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

              this.emitEvent(sessionId, {
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
            this.emitEvent(sessionId, {
              type: 'stateUpdate',
              state: session.state,
              partialText: ''
            });
          } else if (block?.type === 'tool_use' && block.name) {
            console.log(`[ClaudeManager] Tool start: ${block.name}`);
            session.partialText = '';
            session.state = { type: 'tool', toolName: block.name };
            session.pendingTools.set(block.id, block.name);
            this.emitEvent(sessionId, {
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
            this.emitEvent(sessionId, { type: 'text', content: delta.text });
          }
        }

        // 블록 종료 - thinking으로 전환
        if (event.type === 'content_block_stop') {
          session.state = { type: 'thinking' };
          this.emitEvent(sessionId, {
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
          this.emitEvent(sessionId, {
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

        this.emitEvent(sessionId, {
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
  async handlePermission(sessionId, toolName, input) {
    // 해당 대화의 퍼미션 모드 가져오기
    const mode = ClaudeManager.getPermissionMode(sessionId);

    // bypassPermissions: 모든 도구 자동 허용 (AskUserQuestion 제외)
    if (mode === 'bypassPermissions' && toolName !== 'AskUserQuestion') {
      console.log(`[ClaudeManager] Bypass mode - auto-allow: ${toolName}`);
      return { behavior: 'allow', updatedInput: input };
    }

    // acceptEdits: Edit, Write, Bash 등 자동 허용
    if (mode === 'acceptEdits') {
      const editTools = ['Edit', 'Write', 'Bash', 'NotebookEdit'];
      if (editTools.includes(toolName)) {
        console.log(`[ClaudeManager] AcceptEdits mode - auto-allow: ${toolName}`);
        return { behavior: 'allow', updatedInput: input };
      }
    }

    // 자동 허용 (Read, Glob 등)
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
      this.pendingPermissions.set(toolUseId, { resolve, toolName, input, sessionId });

      const permEvent = {
        type: 'permission_request',
        toolName,
        toolInput: input,
        toolUseId
      };
      this.pendingEvents.set(sessionId, permEvent);
      this.emitEvent(sessionId, { type: 'state', state: 'permission' });
      this.emitEvent(sessionId, permEvent);
    });
  }

  /**
   * 실행 중지 (강제 종료)
   * - 세션 유무와 관계없이 항상 idle 상태로 전환
   * - abort 실패해도 세션 정리
   */
  stop(sessionId) {
    console.log(`[ClaudeManager] Force stopping: ${sessionId}`);

    const session = this.sessions.get(sessionId);

    // 1. abort 시도 (실패해도 계속 진행)
    if (session?.abortController) {
      try {
        session.abortController.abort();
        console.log(`[ClaudeManager] Abort signal sent`);
      } catch (err) {
        console.log(`[ClaudeManager] Abort failed: ${err.message}`);
      }
    }

    // 2. 세션 강제 삭제
    this.sessions.delete(sessionId);

    // 3. 상태 강제 변경
    this.emitEvent(sessionId, { type: 'state', state: 'idle' });

    // 4. 대기 중인 권한 요청 모두 거부
    for (const [id, pending] of this.pendingPermissions) {
      try {
        pending.resolve({ behavior: 'deny', message: 'Stopped' });
      } catch (e) {}
    }
    this.pendingPermissions.clear();

    for (const [id, pending] of this.pendingQuestions) {
      try {
        pending.resolve({ behavior: 'deny', message: 'Stopped' });
      } catch (e) {}
    }
    this.pendingQuestions.clear();

    console.log(`[ClaudeManager] ${sessionId} force stopped`);
  }

  /**
   * 새 세션 시작
   */
  newSession(sessionId) {
    this.stop(sessionId);
    this.emitEvent(sessionId, { type: 'state', state: 'idle' });
    console.log(`[ClaudeManager] New session for: ${sessionId}`);
  }

  /**
   * 권한 응답
   */
  respondPermission(sessionId, toolUseId, decision) {
    const pending = this.pendingPermissions.get(toolUseId);
    if (pending) {
      console.log(`[ClaudeManager] Permission ${decision} for ${pending.toolName}`);
      this.pendingPermissions.delete(toolUseId);
      this.pendingEvents.delete(sessionId);
      this.log(sessionId, 'input', { type: 'permission_response', toolUseId, decision });

      if (decision === 'allow' || decision === 'allowAll') {
        pending.resolve({ behavior: 'allow', updatedInput: pending.input });
      } else {
        pending.resolve({ behavior: 'deny', message: 'User denied' });
      }

      this.emitEvent(sessionId, { type: 'state', state: 'working' });
    }
  }

  /**
   * 질문 응답
   */
  respondQuestion(sessionId, toolUseId, answer) {
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
      this.pendingEvents.delete(sessionId);
      this.log(sessionId, 'input', { type: 'question_response', toolUseId: foundId, answer });

      const updatedInput = {
        ...pending.input,
        answers: { '0': answer }
      };
      pending.resolve({ behavior: 'allow', updatedInput });
    }
  }

  /**
   * 특정 세션의 pending 이벤트 가져오기
   */
  getPendingEvent(sessionId) {
    return this.pendingEvents.get(sessionId) || null;
  }

  /**
   * 모든 pending 이벤트 가져오기
   */
  getAllPendingEvents() {
    const result = [];
    for (const [sessionId, event] of this.pendingEvents) {
      result.push({ sessionId, event });
    }
    return result;
  }

  /**
   * 특정 세션에 활성 세션이 있는지 확인
   */
  hasActiveSession(sessionId) {
    return this.sessions.has(sessionId);
  }

  /**
   * 세션 시작 시간 가져오기
   */
  getSessionStartTime(sessionId) {
    const session = this.sessions.get(sessionId);
    return session?.startTime || null;
  }

  /**
   * 모든 활성 세션 ID 목록
   */
  getActiveSessionIds() {
    return Array.from(this.sessions.keys());
  }

  /**
   * 정리
   */
  cleanup() {
    this.sessions.forEach((session, sessionId) => {
      this.stop(sessionId);
    });

    if (this.logStream) {
      this.logStream.end();
    }
  }
}

export default ClaudeManager;
