import React, { useState, useEffect, useRef } from 'react';

const PYLON_URL = 'ws://localhost:9000';

function App() {
  const [pylonConnected, setPylonConnected] = useState(false);
  const [relayConnected, setRelayConnected] = useState(false);
  const [devices, setDevices] = useState([]);
  const [chatMessages, setChatMessages] = useState([]);
  const [chatInput, setChatInput] = useState('');
  const [logs, setLogs] = useState([]);
  const [activeTab, setActiveTab] = useState('chat'); // 'chat' or 'logs'
  const wsRef = useRef(null);
  const isCleaningUp = useRef(false);
  const chatEndRef = useRef(null);

  const addLog = (text, type = 'info') => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prev => [...prev, { timestamp, text, type }].slice(-100));
  };

  const connectToPylon = () => {
    if (wsRef.current) {
      wsRef.current.close();
    }

    addLog('Connecting to Pylon...', 'info');
    const ws = new WebSocket(PYLON_URL);

    ws.onopen = () => {
      setPylonConnected(true);
      addLog('Connected to Pylon', 'success');
      // 디바이스 목록 요청
      ws.send(JSON.stringify({ type: 'getDevices' }));
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);

        // Relay 상태 업데이트
        if (data.type === 'connected') {
          setRelayConnected(data.relayStatus || false);
        }
        if (data.type === 'relayStatus') {
          setRelayConnected(data.connected);
        }

        // Relay에서 온 메시지 처리
        if (data.type === 'fromRelay' && data.data) {
          const relayData = data.data;

          // 디바이스 상태 업데이트
          if (relayData.type === 'deviceStatus' || relayData.type === 'deviceList') {
            setDevices(relayData.devices || []);
            addLog(`Devices: ${(relayData.devices || []).length} connected`, 'info');
          }

          // 채팅 메시지
          if (relayData.type === 'chat') {
            setChatMessages(prev => [...prev, {
              from: relayData.from,
              deviceType: relayData.deviceType,
              message: relayData.message,
              timestamp: relayData.timestamp,
              time: new Date(relayData.timestamp).toLocaleTimeString()
            }].slice(-200));
          }

          // 등록 확인
          if (relayData.type === 'registered') {
            addLog(`Registered as: ${relayData.deviceId}`, 'success');
          }
        }

        // 로그에 추가 (채팅 제외)
        if (data.type !== 'fromRelay' || (data.data && data.data.type !== 'chat')) {
          addLog(`Received: ${JSON.stringify(data).substring(0, 100)}...`, 'message');
        }
      } catch (err) {
        addLog(`Received raw: ${event.data}`, 'message');
      }
    };

    ws.onclose = () => {
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

  useEffect(() => {
    isCleaningUp.current = false;
    connectToPylon();
    return () => {
      isCleaningUp.current = true;
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, []);

  // 채팅 자동 스크롤
  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatMessages]);

  const sendChat = () => {
    if (!chatInput.trim() || !wsRef.current || !pylonConnected) return;

    wsRef.current.send(JSON.stringify({
      type: 'chat',
      message: chatInput
    }));
    setChatInput('');
  };

  const handleChatKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendChat();
    }
  };

  return (
    <div className="app">
      <header className="header">
        <h1>Estelle Desktop <span style={{fontSize: '12px', opacity: 0.7}}>v1.0.0</span></h1>
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
        {/* 디바이스 상태 */}
        <div className="devices-section">
          <h3>Connected Devices ({devices.length})</h3>
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

        {/* 탭 */}
        <div className="tabs">
          <button
            className={`tab ${activeTab === 'chat' ? 'active' : ''}`}
            onClick={() => setActiveTab('chat')}
          >
            Chat
          </button>
          <button
            className={`tab ${activeTab === 'logs' ? 'active' : ''}`}
            onClick={() => setActiveTab('logs')}
          >
            Logs
          </button>
        </div>

        {/* 채팅 탭 */}
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

        {/* 로그 탭 */}
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
