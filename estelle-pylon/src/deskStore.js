/**
 * Desk Store - 데스크 영속 저장
 */

import fs from 'fs';
import path from 'path';

const DESKS_FILE = path.join(process.cwd(), 'desks.json');
const SETTINGS_FILE = path.join(process.cwd(), 'pylon-settings.json');
const DEFAULT_WORKING_DIR = process.env.DEFAULT_WORKING_DIR || 'C:\\Workspace';

function generateDeskId() {
  return `desk_${Date.now().toString(36)}_${Math.random().toString(36).substring(2, 7)}`;
}

function loadSettings() {
  try {
    if (fs.existsSync(SETTINGS_FILE)) {
      return JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf-8'));
    }
  } catch (err) {
    console.error('[DeskStore] Failed to load settings:', err.message);
  }
  return {};
}

function saveSettings(settings) {
  try {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
  } catch (err) {
    console.error('[DeskStore] Failed to save settings:', err.message);
  }
}

const deskStore = {
  load() {
    try {
      if (fs.existsSync(DESKS_FILE)) {
        return JSON.parse(fs.readFileSync(DESKS_FILE, 'utf-8'));
      }
    } catch (err) {
      console.error('[DeskStore] Failed to load:', err.message);
    }
    return { activeDeskId: null, desks: [] };
  },

  save(store) {
    try {
      fs.writeFileSync(DESKS_FILE, JSON.stringify(store, null, 2));
    } catch (err) {
      console.error('[DeskStore] Failed to save:', err.message);
    }
  },

  initialize() {
    const store = this.load();
    console.log(`[DeskStore] Loaded ${store.desks.length} desk(s)`);
    return store;
  },

  getAllDesks() {
    const store = this.load();
    return store.desks.map(d => ({
      ...d,
      isActive: d.deskId === store.activeDeskId
    }));
  },

  getActiveDesk() {
    const store = this.load();
    return store.desks.find(d => d.deskId === store.activeDeskId) || null;
  },

  getDesk(deskId) {
    const store = this.load();
    return store.desks.find(d => d.deskId === deskId) || null;
  },

  createDesk(name, workingDir = DEFAULT_WORKING_DIR) {
    const store = this.load();
    const newDesk = {
      deskId: generateDeskId(),
      name,
      workingDir,
      claudeSessionId: null,
      createdAt: Date.now(),
      lastUsed: Date.now(),
      status: 'idle',
      isActive: false
    };
    store.desks.push(newDesk);
    this.save(store);
    console.log(`[DeskStore] Created desk: ${name}`);
    return newDesk;
  },

  setActiveDesk(deskId) {
    const store = this.load();
    const desk = store.desks.find(d => d.deskId === deskId);
    if (!desk) return false;

    store.activeDeskId = deskId;
    desk.lastUsed = Date.now();
    this.save(store);
    console.log(`[DeskStore] Switched to desk: ${desk.name}`);
    return true;
  },

  renameDesk(deskId, newName) {
    const store = this.load();
    const desk = store.desks.find(d => d.deskId === deskId);
    if (!desk) return false;

    desk.name = newName;
    this.save(store);
    console.log(`[DeskStore] Renamed desk to: ${newName}`);
    return true;
  },

  deleteDesk(deskId) {
    const store = this.load();
    const idx = store.desks.findIndex(d => d.deskId === deskId);
    if (idx < 0) return false;

    store.desks.splice(idx, 1);

    if (store.activeDeskId === deskId) {
      store.activeDeskId = store.desks[0]?.deskId || null;
    }

    this.save(store);
    console.log(`[DeskStore] Deleted desk: ${deskId}`);
    return true;
  },

  updateDeskStatus(deskId, status) {
    const store = this.load();
    const desk = store.desks.find(d => d.deskId === deskId);
    if (!desk) return false;

    desk.status = status;
    this.save(store);
    return true;
  },

  updateClaudeSessionId(deskId, sessionId) {
    const store = this.load();
    const desk = store.desks.find(d => d.deskId === deskId);
    if (!desk) return false;

    desk.claudeSessionId = sessionId;
    desk.lastUsed = Date.now();
    this.save(store);
    console.log(`[DeskStore] Updated session for ${desk.name}: ${sessionId?.substring(0, 8)}...`);
    return true;
  },

  findDeskByName(name) {
    const store = this.load();
    const lowerName = name.toLowerCase();
    return store.desks.find(d => d.name.toLowerCase() === lowerName)
      || store.desks.find(d => d.name.toLowerCase().includes(lowerName))
      || null;
  },

  getPermissionMode() {
    const settings = loadSettings();
    return settings.permissionMode || 'default';
  },

  setPermissionMode(mode) {
    const settings = loadSettings();
    settings.permissionMode = mode;
    saveSettings(settings);
    console.log(`[DeskStore] Permission mode set to: ${mode}`);
  }
};

export default deskStore;
