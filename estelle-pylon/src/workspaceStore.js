/**
 * Workspace Store - 워크스페이스 영속 저장
 *
 * 구조:
 * {
 *   workspaceId: "uuid",
 *   name: "Estelle",
 *   workingDir: "C:\\workspace\\estelle",
 *   conversations: [
 *     {
 *       conversationId: "uuid",
 *       name: "기능 논의",
 *       claudeSessionId: "session-uuid",
 *       status: "idle",  // idle/working/waiting/error
 *       unread: false
 *     }
 *   ]
 * }
 */

import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';

const WORKSPACES_FILE = path.join(process.cwd(), 'workspaces.json');
const SETTINGS_FILE = path.join(process.cwd(), 'pylon-settings.json');
const DEFAULT_WORKING_DIR = process.env.DEFAULT_WORKING_DIR || 'C:\\workspace';

function loadSettings() {
  try {
    if (fs.existsSync(SETTINGS_FILE)) {
      return JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf-8'));
    }
  } catch (err) {
    console.error('[WorkspaceStore] Failed to load settings:', err.message);
  }
  return {};
}

function saveSettings(settings) {
  try {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
  } catch (err) {
    console.error('[WorkspaceStore] Failed to save settings:', err.message);
  }
}

const workspaceStore = {
  load() {
    try {
      if (fs.existsSync(WORKSPACES_FILE)) {
        return JSON.parse(fs.readFileSync(WORKSPACES_FILE, 'utf-8'));
      }
    } catch (err) {
      console.error('[WorkspaceStore] Failed to load:', err.message);
    }
    return { activeWorkspaceId: null, activeConversationId: null, workspaces: [] };
  },

  save(store) {
    try {
      fs.writeFileSync(WORKSPACES_FILE, JSON.stringify(store, null, 2));
    } catch (err) {
      console.error('[WorkspaceStore] Failed to save:', err.message);
    }
  },

  initialize() {
    const store = this.load();
    console.log(`[WorkspaceStore] Loaded ${store.workspaces.length} workspace(s)`);
    return store;
  },

  // ========== Workspace CRUD ==========

  getAllWorkspaces() {
    const store = this.load();
    return store.workspaces.map(w => ({
      ...w,
      isActive: w.workspaceId === store.activeWorkspaceId
    }));
  },

  getActiveWorkspace() {
    const store = this.load();
    return store.workspaces.find(w => w.workspaceId === store.activeWorkspaceId) || null;
  },

  getWorkspace(workspaceId) {
    const store = this.load();
    return store.workspaces.find(w => w.workspaceId === workspaceId) || null;
  },

  createWorkspace(name, workingDir = DEFAULT_WORKING_DIR) {
    const store = this.load();

    // 첫 번째 대화 자동 생성
    const firstConversation = {
      conversationId: randomUUID(),
      name: '새 대화',
      claudeSessionId: null,
      status: 'idle',
      unread: false,
      createdAt: Date.now()
    };

    const newWorkspace = {
      workspaceId: randomUUID(),
      name,
      workingDir,
      conversations: [firstConversation],
      createdAt: Date.now(),
      lastUsed: Date.now()
    };

    store.workspaces.push(newWorkspace);
    store.activeWorkspaceId = newWorkspace.workspaceId;
    store.activeConversationId = firstConversation.conversationId;
    this.save(store);

    console.log(`[WorkspaceStore] Created workspace: ${name}`);
    return { workspace: newWorkspace, conversation: firstConversation };
  },

  deleteWorkspace(workspaceId) {
    const store = this.load();
    const idx = store.workspaces.findIndex(w => w.workspaceId === workspaceId);
    if (idx < 0) return false;

    store.workspaces.splice(idx, 1);

    if (store.activeWorkspaceId === workspaceId) {
      const nextWorkspace = store.workspaces[0];
      store.activeWorkspaceId = nextWorkspace?.workspaceId || null;
      store.activeConversationId = nextWorkspace?.conversations[0]?.conversationId || null;
    }

    this.save(store);
    console.log(`[WorkspaceStore] Deleted workspace: ${workspaceId}`);
    return true;
  },

  renameWorkspace(workspaceId, newName) {
    const store = this.load();
    const workspace = store.workspaces.find(w => w.workspaceId === workspaceId);
    if (!workspace) return false;

    workspace.name = newName;
    this.save(store);
    console.log(`[WorkspaceStore] Renamed workspace to: ${newName}`);
    return true;
  },

  setActiveWorkspace(workspaceId, conversationId = null) {
    const store = this.load();
    const workspace = store.workspaces.find(w => w.workspaceId === workspaceId);
    if (!workspace) return false;

    store.activeWorkspaceId = workspaceId;
    workspace.lastUsed = Date.now();

    // conversationId가 주어지면 해당 대화 활성화, 아니면 첫 번째 대화
    if (conversationId) {
      const conv = workspace.conversations.find(c => c.conversationId === conversationId);
      store.activeConversationId = conv ? conversationId : workspace.conversations[0]?.conversationId;
    } else {
      store.activeConversationId = workspace.conversations[0]?.conversationId || null;
    }

    this.save(store);
    console.log(`[WorkspaceStore] Switched to workspace: ${workspace.name}`);
    return true;
  },

  // ========== Conversation CRUD ==========

  getConversation(workspaceId, conversationId) {
    const workspace = this.getWorkspace(workspaceId);
    if (!workspace) return null;
    return workspace.conversations.find(c => c.conversationId === conversationId) || null;
  },

  findWorkspaceByConversation(conversationId) {
    const store = this.load();
    for (const workspace of store.workspaces) {
      if (workspace.conversations.some(c => c.conversationId === conversationId)) {
        return workspace.workspaceId;
      }
    }
    return null;
  },

  getActiveConversation() {
    const store = this.load();
    if (!store.activeWorkspaceId || !store.activeConversationId) return null;

    const workspace = store.workspaces.find(w => w.workspaceId === store.activeWorkspaceId);
    if (!workspace) return null;

    return workspace.conversations.find(c => c.conversationId === store.activeConversationId) || null;
  },

  createConversation(workspaceId, name = '새 대화', skillType = 'general') {
    const store = this.load();
    const workspace = store.workspaces.find(w => w.workspaceId === workspaceId);
    if (!workspace) return null;

    const newConversation = {
      conversationId: randomUUID(),
      name,
      skillType, // general, planner, worker
      claudeSessionId: null,
      status: 'idle',
      unread: false,
      createdAt: Date.now()
    };

    workspace.conversations.push(newConversation);
    workspace.lastUsed = Date.now();
    store.activeConversationId = newConversation.conversationId;
    this.save(store);

    console.log(`[WorkspaceStore] Created conversation: ${name} (${skillType}) in ${workspace.name}`);
    return newConversation;
  },

  deleteConversation(workspaceId, conversationId) {
    const store = this.load();
    const workspace = store.workspaces.find(w => w.workspaceId === workspaceId);
    if (!workspace) return false;

    const idx = workspace.conversations.findIndex(c => c.conversationId === conversationId);
    if (idx < 0) return false;

    workspace.conversations.splice(idx, 1);

    // 삭제된 대화가 활성 대화였으면 다른 대화로 전환
    if (store.activeConversationId === conversationId) {
      store.activeConversationId = workspace.conversations[0]?.conversationId || null;
    }

    this.save(store);
    console.log(`[WorkspaceStore] Deleted conversation: ${conversationId}`);
    return true;
  },

  renameConversation(workspaceId, conversationId, newName) {
    const store = this.load();
    const workspace = store.workspaces.find(w => w.workspaceId === workspaceId);
    if (!workspace) return false;

    const conv = workspace.conversations.find(c => c.conversationId === conversationId);
    if (!conv) return false;

    conv.name = newName;
    this.save(store);
    console.log(`[WorkspaceStore] Renamed conversation to: ${newName}`);
    return true;
  },

  updateConversationStatus(workspaceId, conversationId, status) {
    const store = this.load();
    const workspace = store.workspaces.find(w => w.workspaceId === workspaceId);
    if (!workspace) return false;

    const conv = workspace.conversations.find(c => c.conversationId === conversationId);
    if (!conv) return false;

    conv.status = status;
    this.save(store);
    return true;
  },

  updateConversationUnread(workspaceId, conversationId, unread) {
    const store = this.load();
    const workspace = store.workspaces.find(w => w.workspaceId === workspaceId);
    if (!workspace) return false;

    const conv = workspace.conversations.find(c => c.conversationId === conversationId);
    if (!conv) return false;

    conv.unread = unread;
    this.save(store);
    return true;
  },

  updateClaudeSessionId(workspaceId, conversationId, sessionId) {
    const store = this.load();
    const workspace = store.workspaces.find(w => w.workspaceId === workspaceId);
    if (!workspace) return false;

    const conv = workspace.conversations.find(c => c.conversationId === conversationId);
    if (!conv) return false;

    conv.claudeSessionId = sessionId;
    workspace.lastUsed = Date.now();
    this.save(store);
    console.log(`[WorkspaceStore] Updated session for ${conv.name}: ${sessionId?.substring(0, 8)}...`);
    return true;
  },

  setActiveConversation(conversationId) {
    const store = this.load();
    store.activeConversationId = conversationId;
    this.save(store);
    return true;
  },

  // ========== 대화별 퍼미션 모드 ==========

  getConversationPermissionMode(conversationId) {
    const store = this.load();
    for (const workspace of store.workspaces) {
      const conv = workspace.conversations.find(c => c.conversationId === conversationId);
      if (conv) return conv.permissionMode || 'default';
    }
    return 'default';
  },

  setConversationPermissionMode(conversationId, mode) {
    const store = this.load();
    for (const workspace of store.workspaces) {
      const conv = workspace.conversations.find(c => c.conversationId === conversationId);
      if (conv) {
        conv.permissionMode = mode;
        this.save(store);
        console.log(`[WorkspaceStore] Conversation ${conversationId} permission mode: ${mode}`);
        return true;
      }
    }
    return false;
  },

  // ========== Utility ==========

  findWorkspaceByName(name) {
    const store = this.load();
    const lowerName = name.toLowerCase();
    return store.workspaces.find(w => w.name.toLowerCase() === lowerName)
      || store.workspaces.find(w => w.name.toLowerCase().includes(lowerName))
      || null;
  },

  findConversationByWorkingDir(workingDir) {
    const store = this.load();
    return store.workspaces.find(w => w.workingDir === workingDir) || null;
  },

  // 활성 상태 정보
  getActiveState() {
    const store = this.load();
    return {
      activeWorkspaceId: store.activeWorkspaceId,
      activeConversationId: store.activeConversationId
    };
  },

  /**
   * 시작 시 working/waiting 상태인 대화들을 idle로 초기화
   * @returns {Array} 초기화된 대화 ID 목록
   */
  resetActiveConversations() {
    const store = this.load();
    const resetConversationIds = [];

    for (const workspace of store.workspaces) {
      for (const conv of workspace.conversations) {
        if (conv.status === 'working' || conv.status === 'waiting') {
          conv.status = 'idle';
          resetConversationIds.push(conv.conversationId);
          console.log(`[WorkspaceStore] Reset conversation status: ${conv.name} (${conv.conversationId})`);
        }
      }
    }

    if (resetConversationIds.length > 0) {
      this.save(store);
    }

    return resetConversationIds;
  }
};

export default workspaceStore;
