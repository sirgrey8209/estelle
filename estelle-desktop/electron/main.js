const { app, BrowserWindow, ipcMain, shell } = require('electron');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');

let mainWindow;

const isDev = process.env.NODE_ENV === 'development' || !app.isPackaged;
const DEPLOY_JSON_URL = 'https://github.com/sirgrey8209/estelle/releases/download/deploy/deploy.json';
const REPO_DIR = path.resolve(__dirname, '..', '..');

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 900,
    height: 700,
    minWidth: 600,
    minHeight: 500,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    titleBarStyle: 'default',
    show: false,
  });

  // 개발 모드면 Vite dev server, 아니면 빌드된 파일
  if (isDev) {
    mainWindow.loadURL('http://localhost:5173');
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'));
  }

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// ============ 자동 업데이트 ============

function fetchDeployJson() {
  return new Promise((resolve) => {
    const url = `${DEPLOY_JSON_URL}?t=${Date.now()}`;
    https.get(url, { headers: { 'User-Agent': 'Estelle-Desktop' } }, (res) => {
      if (res.statusCode === 302 || res.statusCode === 301) {
        https.get(res.headers.location, (res2) => {
          let data = '';
          res2.on('data', chunk => data += chunk);
          res2.on('end', () => { try { resolve(JSON.parse(data)); } catch { resolve(null); } });
        }).on('error', () => resolve(null));
        return;
      }
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => { try { resolve(JSON.parse(data)); } catch { resolve(null); } });
    }).on('error', () => resolve(null));
  });
}

function getLocalCommit() {
  try {
    return execSync('git rev-parse --short HEAD', { cwd: REPO_DIR, encoding: 'utf-8' }).trim();
  } catch {
    return null;
  }
}

async function checkForUpdate() {
  const localCommit = getLocalCommit();
  const deployInfo = await fetchDeployJson();

  return {
    localCommit,
    deployCommit: deployInfo?.commit || null,
    hasUpdate: localCommit && deployInfo?.commit && localCommit !== deployInfo.commit
  };
}

async function runUpdate() {
  try {
    const deployInfo = await fetchDeployJson();
    if (!deployInfo) {
      return { success: false, message: 'Could not fetch deploy info' };
    }

    execSync('git fetch origin', { cwd: REPO_DIR, encoding: 'utf-8' });
    execSync(`git checkout ${deployInfo.commit}`, { cwd: REPO_DIR, encoding: 'utf-8' });

    const desktopDir = path.join(REPO_DIR, 'estelle-desktop');
    execSync('npm install', { cwd: desktopDir, encoding: 'utf-8' });
    execSync('npm run build', { cwd: desktopDir, encoding: 'utf-8' });

    return { success: true, message: `Updated to ${deployInfo.commit}` };
  } catch (err) {
    return { success: false, message: err.message };
  }
}

// ============ IPC 핸들러 ============

ipcMain.handle('get-app-info', () => {
  return {
    version: app.getVersion(),
    platform: process.platform,
    commit: getLocalCommit(),
  };
});

ipcMain.handle('check-update', async () => {
  return await checkForUpdate();
});

ipcMain.handle('run-update', async () => {
  const result = await runUpdate();
  if (result.success) {
    // 업데이트 성공 시 앱 재시작
    setTimeout(() => {
      app.relaunch();
      app.exit(0);
    }, 1000);
  }
  return result;
});

ipcMain.handle('open-external', (event, url) => {
  shell.openExternal(url);
});
