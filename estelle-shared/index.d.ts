/**
 * Estelle Shared Types
 * Phase 2: Claude Code 원격 제어
 */

// ============ 캐릭터 ============

export interface Character {
  name: string;
  icon: string;
  description: string;
}

export const CHARACTERS: Record<string, Character>;

// ============ 디바이스 ============

export type DeviceType = 'pylon' | 'desktop' | 'mobile' | 'relay';

export interface DeviceId {
  pcId: string;
  deviceType: DeviceType;
}

// ============ 메시지 ============

export const MessageType: {
  AUTH: 'auth';
  AUTH_RESULT: 'auth_result';
  CONNECTED: 'connected';
  REGISTERED: 'registered';
  DEVICE_STATUS: 'device_status';
  DESK_LIST: 'desk_list';
  DESK_LIST_RESULT: 'desk_list_result';
  DESK_SWITCH: 'desk_switch';
  DESK_CREATE: 'desk_create';
  DESK_DELETE: 'desk_delete';
  DESK_RENAME: 'desk_rename';
  DESK_STATUS: 'desk_status';
  CLAUDE_SEND: 'claude_send';
  CLAUDE_EVENT: 'claude_event';
  CLAUDE_PERMISSION: 'claude_permission';
  CLAUDE_ANSWER: 'claude_answer';
  CLAUDE_CONTROL: 'claude_control';
  CLAUDE_SET_PERMISSION_MODE: 'claude_set_permission_mode';
  PING: 'ping';
  PONG: 'pong';
  ERROR: 'error';
};

export interface Message<T = any> {
  type: string;
  payload: T;
  from?: DeviceId | null;
  to?: DeviceId | null;
  timestamp: number;
  requestId?: string | null;
}

// ============ 인증 ============

export interface AuthPayload {
  pcId: string;
  deviceType: DeviceType;
  mac?: string;
}

export interface AuthResultPayload {
  success: boolean;
  error?: string;
  deviceId?: DeviceId;
}

// ============ 데스크 ============

export const DeskStatus: {
  IDLE: 'idle';
  WORKING: 'working';
  PERMISSION: 'permission';
  OFFLINE: 'offline';
};

export type DeskStatusType = 'idle' | 'working' | 'permission' | 'offline';

export interface DeskInfo {
  pcId: string;
  pcName: string;
  deskId: string;
  deskName: string;
  workingDir: string;
  status: DeskStatusType;
  isActive: boolean;
}

export interface DeskListResultPayload {
  desks: DeskInfo[];
}

// ============ Claude 이벤트 ============

export const ClaudeEventType: {
  STATE: 'state';
  TEXT: 'text';
  TOOL_START: 'tool_start';
  TOOL_COMPLETE: 'tool_complete';
  PERMISSION_REQUEST: 'permission_request';
  ASK_QUESTION: 'ask_question';
  RESULT: 'result';
  ERROR: 'error';
};

export interface ClaudeStateEvent {
  type: 'state';
  state: string;
}

export interface ClaudeTextEvent {
  type: 'text';
  content: string;
}

export interface ClaudeToolStartEvent {
  type: 'tool_start';
  toolName: string;
  toolInput: Record<string, any>;
}

export interface ClaudeToolCompleteEvent {
  type: 'tool_complete';
  toolName: string;
  output: any;
}

export interface ClaudePermissionRequestEvent {
  type: 'permission_request';
  toolName: string;
  toolInput: Record<string, any>;
  toolUseId: string;
}

export interface ClaudeAskQuestionEvent {
  type: 'ask_question';
  question: string;
  options: string[];
  toolUseId: string;
}

export interface ClaudeResultEvent {
  type: 'result';
  result: any;
}

export interface ClaudeErrorEvent {
  type: 'error';
  error: string;
}

export type ClaudeEvent =
  | ClaudeStateEvent
  | ClaudeTextEvent
  | ClaudeToolStartEvent
  | ClaudeToolCompleteEvent
  | ClaudePermissionRequestEvent
  | ClaudeAskQuestionEvent
  | ClaudeResultEvent
  | ClaudeErrorEvent;

export interface ClaudeEventPayload {
  deskId: string;
  event: ClaudeEvent;
}

// ============ Claude 제어 ============

export interface ClaudeSendPayload {
  deskId: string;
  message: string;
}

export interface ClaudePermissionPayload {
  deskId: string;
  toolUseId: string;
  decision: 'allow' | 'deny' | 'allowAll';
}

export interface ClaudeAnswerPayload {
  deskId: string;
  toolUseId: string;
  answer: string;
}

export interface ClaudeControlPayload {
  deskId: string;
  action: 'stop' | 'new_session' | 'clear' | 'compact';
}

// ============ 권한 모드 ============

export const PermissionMode: {
  DEFAULT: 'default';
  ACCEPT_EDITS: 'acceptEdits';
  BYPASS: 'bypassPermissions';
};

export type PermissionModeType = 'default' | 'acceptEdits' | 'bypassPermissions';

export interface SetPermissionModePayload {
  mode: PermissionModeType;
}

// ============ 헬퍼 함수 ============

export function createMessage<T>(
  type: string,
  payload: T,
  options?: { from?: DeviceId; to?: DeviceId; requestId?: string }
): Message<T>;

export function getCharacter(pcId: string): Character;

export function getDeskFullName(pcId: string, deskName: string): string;
