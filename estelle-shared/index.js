/**
 * Estelle Shared - 공유 타입과 상수
 * Phase 2: Claude Code 원격 제어
 */

// ============ 캐릭터 ============

const CHARACTERS = {
  stella: { name: 'Stella', icon: '⭐', description: '회사 PC' },
  selene: { name: 'Selene', icon: '🌙', description: '집 PC' },
  lucy: { name: 'Lucy', icon: '📱', description: 'Mobile' },
  estelle: { name: 'Estelle', icon: '💫', description: 'Relay' }
};

// ============ 메시지 타입 ============

const MessageType = {
  // 인증
  AUTH: 'auth',
  AUTH_RESULT: 'auth_result',

  // 연결 상태
  CONNECTED: 'connected',
  REGISTERED: 'registered',
  DEVICE_STATUS: 'device_status',

  // 데스크 관리
  DESK_LIST: 'desk_list',
  DESK_LIST_RESULT: 'desk_list_result',
  DESK_SWITCH: 'desk_switch',
  DESK_CREATE: 'desk_create',
  DESK_DELETE: 'desk_delete',
  DESK_RENAME: 'desk_rename',
  DESK_STATUS: 'desk_status',

  // Claude 제어
  CLAUDE_SEND: 'claude_send',
  CLAUDE_EVENT: 'claude_event',
  CLAUDE_PERMISSION: 'claude_permission',
  CLAUDE_ANSWER: 'claude_answer',
  CLAUDE_CONTROL: 'claude_control',
  CLAUDE_SET_PERMISSION_MODE: 'claude_set_permission_mode',

  // 기타
  PING: 'ping',
  PONG: 'pong',
  ERROR: 'error'
};

// ============ 데스크 상태 ============

const DeskStatus = {
  IDLE: 'idle',
  WORKING: 'working',
  PERMISSION: 'permission',
  OFFLINE: 'offline'
};

// ============ Claude 이벤트 타입 ============

const ClaudeEventType = {
  STATE: 'state',
  TEXT: 'text',
  TOOL_START: 'tool_start',
  TOOL_COMPLETE: 'tool_complete',
  PERMISSION_REQUEST: 'permission_request',
  ASK_QUESTION: 'ask_question',
  RESULT: 'result',
  ERROR: 'error'
};

// ============ 권한 모드 ============

const PermissionMode = {
  DEFAULT: 'default',
  ACCEPT_EDITS: 'acceptEdits',
  BYPASS: 'bypassPermissions'
};

// ============ 헬퍼 함수 ============

/**
 * 메시지 생성 헬퍼
 */
function createMessage(type, payload, options = {}) {
  return {
    type,
    payload,
    from: options.from || null,
    to: options.to || null,
    timestamp: Date.now(),
    requestId: options.requestId || null
  };
}

/**
 * 캐릭터 정보 가져오기
 */
function getCharacter(pcId) {
  return CHARACTERS[pcId] || { name: pcId, icon: '💻', description: 'Unknown PC' };
}

/**
 * 데스크 전체 이름 생성 (캐릭터/데스크)
 */
function getDeskFullName(pcId, deskName) {
  const char = getCharacter(pcId);
  return `${char.name}/${deskName}`;
}

// ============ Exports ============

module.exports = {
  CHARACTERS,
  MessageType,
  DeskStatus,
  ClaudeEventType,
  PermissionMode,
  createMessage,
  getCharacter,
  getDeskFullName
};
