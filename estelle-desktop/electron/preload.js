const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  getAppInfo: () => ipcRenderer.invoke('get-app-info'),
  checkUpdate: () => ipcRenderer.invoke('check-update'),
  runUpdate: () => ipcRenderer.invoke('run-update'),
  openExternal: (url) => ipcRenderer.invoke('open-external', url),
});
