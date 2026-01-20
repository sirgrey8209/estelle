import React, { useState, useEffect, useRef } from 'react';

const PYLON_URL = 'ws://localhost:9000';
const GITHUB_DEPLOY_URL = 'https://github.com/sirgrey8209/estelle/releases/download/deploy/deploy.json';
const LOCAL_VERSION = '1.0.0';  // package.json과 동기화 필요

// WebSocket을 모듈 레벨에서 관리 (HMR에서 연결 유지)
let globalWs = null;
let globalWsConnected = false;

function App() {
  const [pylonConnected, setPylonConnected] = useState(false);
  const [relayConnected, setRelayConnected] = useState(false);
  const [devices, setDevices] = useState([]);
  const [chatMessages, setChatMessages] = useState([]);
  const [chatInput, setChatInput] = useState('');
  const [logs, setLogs] = useState([]);
  const [activeTab, setActiveTab] = useState('chat');

  // 배포 상태
  const [deployInfo, setDeployInfo] = useState(null);  // GitHub에서 가져온 deploy.json
  const [gitCommit, setGitCommit] = useState(null);    // 현재 Git 커밋
  const [deployStatus, setDeployStatus] = useState('checking');  // 'checking', 'update', 'deploy', 'synced', 'deploying', 'error'
  const [showUpdateModal, setShowUpdateModal] = useState(false);
  const [showRedeployConfirm, setShowRedeployConfirm] = useState(false);
  const [pendingDeploy, setPendingDeploy] = useState(null);  // 실행 중 받은 배포 알림

  const wsRef = useRef(null);
  const isCleaningUp = useRef(false);
  const chatEndRef = useRef(null);

  const addLog = (text, type = 'info') => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prev => [...prev, { timestamp, text, type }].slice(-100));
  };

  // deploy.json 가져오기
  const fetchDeployInfo = async () => {
    try {
      const response = await fetch(GITHUB_DEPLOY_URL + '?t=' + Date.now());
      if (response.ok) {
        const data = await response.json();
        setDeployInfo(data);
        addLog(`Deploy info: ${data.desktop}`, 'info');
        return data;
      }
    } catch (err) {
      addLog('No deploy info found', 'info');
    }
    return null;
  };

  // Git 커밋 가져오기 (Pylon을 통해)
  const fetchGitCommit = () => {
    if (wsRef.current && pylonConnected) {
      wsRef.current.send(JSON.stringify({ type: 'getGitCommit' }));
    }
  };

  // 배포 상태 계산
  const calculateDeployStatus = (deploy, commit) => {
    if (!deploy) {
      setDeployStatus('deploy');  // 첫 배포
      return;
    }

    const localBase = LOCAL_VERSION.split('-')[0];
    const deployedBase = deploy.desktop?.split('-')[0];

    // 로컬 < 배포 → Update 필요
    if (localBase !== deployedBase || LOCAL_VERSION < deploy.desktop) {
      setDeployStatus('update');
      return;
    }

    // Git > 배포 → Deploy 가능
    if (commit && commit !== deploy.commit) {
      setDeployStatus('deploy');
      return;
    }

    // 동일 → Synced
    setDeployStatus('synced');
  };

  // 배포 실행
  const executeDeploy = async (force = false) => {
    if (deployStatus === 'update') {
      // Update 필요 - Pylon에게 업데이트 요청
      addLog('Requesting update...', 'info');
      setDeployStatus('deploying');
      wsRef.current?.send(JSON.stringify({
        type: 'toRelay',
        data: { type: 'update' }
      }));
      return;
    }

    if (deployStatus === 'synced' && !force) {
      // Synced 상태에서 클릭 → 재배포 확인
      setShowRedeployConfirm(true);
      return;
    }

    // Deploy 실행
    addLog('Starting deploy...', 'info');
    setDeployStatus('deploying');

    // Pylon에게 deploy 스크립트 실행 요청
    wsRef.current?.send(JSON.stringify({
      type: 'runDeploy',
      force: force
    }));
  };

  const connectToPylon = () => {
    // 이미 연결된 globalWs가 있으면 재사용
    if (globalWs && globalWs.readyState === WebSocket.OPEN) {
      wsRef.current = globalWs;
      setPylonConnected(true);
      globalWs.send(JSON.stringify({ type: 'getDevices' }));
      globalWs.send(JSON.stringify({ type: 'getGitCommit' }));
      return;
    }

    // 연결 중이면 대기
    if (globalWs && globalWs.readyState === WebSocket.CONNECTING) {
      wsRef.current = globalWs;
      return;
    }

    addLog('Connecting to Pylon...', 'info');
    const ws = new WebSocket(PYLON_URL);
    globalWs = ws;

    ws.onopen = () => {
      globalWsConnected = true;
      setPylonConnected(true);
      addLog('Connected to Pylon', 'success');
      ws.send(JSON.stringify({ type: 'getDevices' }));
      ws.send(JSON.stringify({ type: 'getGitCommit' }));
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);

        if (data.type === 'connected') {
          setRelayConnected(data.relayStatus || false);
        }
        if (data.type === 'relayStatus') {
          setRelayConnected(data.connected);
        }

        // Git 커밋 응답
        if (data.type === 'gitCommit') {
          setGitCommit(data.commit);
          addLog(`Git commit: ${data.commit}`, 'info');
        }

        // 배포 결과
        if (data.type === 'deployResult') {
          if (data.success) {
            addLog('Deploy completed!', 'success');
            fetchDeployInfo();  // 새 배포 정보 가져오기
          } else {
            addLog(`Deploy failed: ${data.message}`, 'error');
            setDeployStatus('error');
          }
        }

        if (data.type === 'fromRelay' && data.data) {
          const relayData = data.data;

          if (relayData.type === 'deviceStatus' || relayData.type === 'deviceList') {
            setDevices(relayData.devices || []);
          }

          if (relayData.type === 'chat') {
            setChatMessages(prev => [...prev, {
              from: relayData.from,
              deviceType: relayData.deviceType,
              message: relayData.message,
              timestamp: relayData.timestamp,
              time: new Date(relayData.timestamp).toLocaleTimeString()
            }].slice(-200));
          }

          if (relayData.type === 'registered') {
            addLog(`Registered as: ${relayData.deviceId}`, 'success');
          }

          // 배포 알림 수신 (실행 중)
          if (relayData.type === 'deployNotification') {
            setPendingDeploy(relayData.deploy);
            setShowUpdateModal(true);
            addLog('New deployment available!', 'notification');
          }

          if (relayData.type === 'updateResult') {
            if (relayData.success) {
              addLog(`Update: ${relayData.message}`, 'success');
              fetchDeployInfo();
            } else {
              addLog(`Update failed: ${relayData.message}`, 'error');
              setDeployStatus('error');
            }
          }
        }

        if (data.type !== 'fromRelay' || (data.data && data.data.type !== 'chat')) {
          addLog(`Received: ${JSON.stringify(data).substring(0, 100)}...`, 'message');
        }
      } catch (err) {
        addLog(`Received raw: ${event.data}`, 'message');
      }
    };

    ws.onclose = () => {
      globalWsConnected = false;
      globalWs = null;
      setPylonConnected(false);
      setRelayConnected(false);
      setDevices([]);
      addLog('Disconnected from Pylon', 'error');

      if (!isCleaningUp.current) {
        setTimeout(connectToPylon, 3000);
      }
    };

    ws.onerror = () => {
      addLog('Connection error', 'error');
    };

    wsRef.current = ws;
  };

  // 초기화
  useEffect(() => {
    isCleaningUp.current = false;
    connectToPylon();
    fetchDeployInfo();

    return () => {
      isCleaningUp.current = true;
      // HMR에서 연결 유지 - cleanup에서 닫지 않음
      // 앱이 완전히 종료될 때는 브라우저가 알아서 닫음
    };
  }, []);

  // deployInfo나 gitCommit 변경 시 상태 재계산
  useEffect(() => {
    calculateDeployStatus(deployInfo, gitCommit);
  }, [deployInfo, gitCommit]);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatMessages]);

  const sendChat = () => {
    if (!chatInput.trim() || !wsRef.current || !pylonConnected) return;
    wsRef.current.send(JSON.stringify({ type: 'chat', message: chatInput }));
    setChatInput('');
  };

  const handleChatKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendChat();
    }
  };

  const getDeployButtonText = () => {
    switch (deployStatus) {
      case 'checking': return 'Checking...';
      case 'update': return 'Update';
      case 'deploy': return 'Deploy';
      case 'synced': return 'Synced';
      case 'deploying': return 'Deploying...';
      case 'error': return 'Error';
      default: return 'Deploy';
    }
  };

  const getDeployButtonClass = () => {
    switch (deployStatus) {
      case 'update': return 'btn-update-needed';
      case 'deploy': return 'btn-deploy';
      case 'synced': return 'btn-synced';
      case 'error': return 'btn-error';
      default: return '';
    }
  };

  return (
    <div className="app">
      {/* 업데이트 모달 */}
      {showUpdateModal && (
        <div className="modal-overlay">
          <div className="modal">
            <h2>Update Available</h2>
            <p>A new version has been deployed.</p>
            {pendingDeploy && (
              <p className="version-info">Version: {pendingDeploy.desktop}</p>
            )}
            <div className="modal-buttons">
              <button className="btn btn-primary" onClick={() => {
                setShowUpdateModal(false);
                executeDeploy();
              }}>
                Update Now
              </button>
              <button className="btn btn-secondary" onClick={() => setShowUpdateModal(false)}>
                Later
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 재배포 확인 모달 */}
      {showRedeployConfirm && (
        <div className="modal-overlay">
          <div className="modal">
            <h2>Redeploy?</h2>
            <p>Versions are identical. Do you want to redeploy?</p>
            <div className="modal-buttons">
              <button className="btn btn-primary" onClick={() => {
                setShowRedeployConfirm(false);
                executeDeploy(true);
              }}>
                Redeploy
              </button>
              <button className="btn btn-secondary" onClick={() => setShowRedeployConfirm(false)}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      <header className="header">
        <h1>Estelle Desktop <span style={{fontSize: '12px', opacity: 0.7}}>v{LOCAL_VERSION}</span></h1>
        <div className="status-bar">
          <span className={`status ${pylonConnected ? 'connected' : 'disconnected'}`}>
            Pylon: {pylonConnected ? 'ON' : 'OFF'}
          </span>
          <span className={`status ${relayConnected ? 'connected' : 'disconnected'}`}>
            Relay: {relayConnected ? 'ON' : 'OFF'}
          </span>
        </div>
      </header>

      <main className="main">
        <div className="devices-section">
          <div className="devices-header">
            <h3>Connected Devices ({devices.length})</h3>
            <button
              onClick={() => executeDeploy()}
              disabled={!pylonConnected || deployStatus === 'checking' || deployStatus === 'deploying'}
              className={`btn btn-deploy-action ${getDeployButtonClass()}`}
            >
              {getDeployButtonText()}
            </button>
          </div>
          <div className="devices-list">
            {devices.length === 0 ? (
              <span className="no-devices">No devices connected</span>
            ) : (
              devices.map((device, i) => (
                <div key={i} className="device-item">
                  <span className="device-icon">
                    {device.deviceType === 'pylon' ? '💻' :
                     device.deviceType === 'mobile' ? '📱' :
                     device.deviceType === 'desktop' ? '🖥️' : '❓'}
                  </span>
                  <span className="device-name">{device.deviceId}</span>
                  <span className="device-type">({device.deviceType})</span>
                </div>
              ))
            )}
          </div>
        </div>

        <div className="tabs">
          <button className={`tab ${activeTab === 'chat' ? 'active' : ''}`} onClick={() => setActiveTab('chat')}>
            Chat
          </button>
          <button className={`tab ${activeTab === 'logs' ? 'active' : ''}`} onClick={() => setActiveTab('logs')}>
            Logs
          </button>
        </div>

        {activeTab === 'chat' && (
          <div className="chat-section">
            <div className="chat-messages">
              {chatMessages.length === 0 ? (
                <div className="no-messages">No messages yet</div>
              ) : (
                chatMessages.map((msg, i) => (
                  <div key={i} className="chat-message">
                    <span className="chat-time">{msg.time}</span>
                    <span className="chat-from">{msg.from}:</span>
                    <span className="chat-text">{msg.message}</span>
                  </div>
                ))
              )}
              <div ref={chatEndRef} />
            </div>
            <div className="chat-input-container">
              <input
                type="text"
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                onKeyPress={handleChatKeyPress}
                placeholder="Type a message..."
                className="chat-input"
                disabled={!pylonConnected || !relayConnected}
              />
              <button
                onClick={sendChat}
                disabled={!pylonConnected || !relayConnected || !chatInput.trim()}
                className="btn btn-primary"
              >
                Send
              </button>
            </div>
          </div>
        )}

        {activeTab === 'logs' && (
          <div className="logs-section">
            <div className="log-container">
              {logs.map((log, i) => (
                <div key={i} className={`log-entry log-${log.type}`}>
                  <span className="log-time">{log.timestamp}</span>
                  <span className="log-text">{log.text}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </main>
    </div>
  );
}

export default App;
