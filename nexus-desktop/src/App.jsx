import React, { useState, useEffect, useRef } from 'react';

const PYLON_URL = 'ws://localhost:9000';

function App() {
  const [pylonConnected, setPylonConnected] = useState(false);
  const [relayConnected, setRelayConnected] = useState(false);
  const [message, setMessage] = useState('');
  const [logs, setLogs] = useState([]);
  const wsRef = useRef(null);

  const addLog = (text, type = 'info') => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prev => [...prev, { timestamp, text, type }].slice(-50));
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
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        addLog(`Received: ${JSON.stringify(data)}`, 'message');

        // Relay 상태 업데이트
        if (data.type === 'connected') {
          setRelayConnected(data.relayStatus || false);
        }
        if (data.type === 'relayStatus') {
          setRelayConnected(data.connected);
        }

        // 알림 처리
        if (data.type === 'notification') {
          addLog(`📢 ${data.title || 'Notification'}: ${data.message}`, 'notification');
        }
      } catch (err) {
        addLog(`Received raw: ${event.data}`, 'message');
      }
    };

    ws.onclose = () => {
      setPylonConnected(false);
      setRelayConnected(false);
      addLog('Disconnected from Pylon', 'error');

      // 재연결 시도
      setTimeout(connectToPylon, 3000);
    };

    ws.onerror = (err) => {
      addLog('Connection error', 'error');
    };

    wsRef.current = ws;
  };

  useEffect(() => {
    connectToPylon();
    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, []);

  const sendEcho = () => {
    if (!message.trim()) return;

    if (wsRef.current && pylonConnected) {
      wsRef.current.send(JSON.stringify({
        type: 'echo',
        payload: message
      }));
      addLog(`Sent echo: ${message}`, 'sent');
      setMessage('');
    } else {
      addLog('Not connected to Pylon', 'error');
    }
  };

  const sendPing = () => {
    if (wsRef.current && pylonConnected) {
      wsRef.current.send(JSON.stringify({ type: 'ping' }));
      addLog('Sent ping', 'sent');
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      sendEcho();
    }
  };

  return (
    <div className="app">
      <header className="header">
        <h1>Nexus Desktop</h1>
        <div className="status-bar">
          <span className={`status ${pylonConnected ? 'connected' : 'disconnected'}`}>
            Pylon: {pylonConnected ? '🟢' : '🔴'}
          </span>
          <span className={`status ${relayConnected ? 'connected' : 'disconnected'}`}>
            Relay: {relayConnected ? '🟢' : '🔴'}
          </span>
        </div>
      </header>

      <main className="main">
        <div className="controls">
          <input
            type="text"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Enter message for echo test..."
            className="input"
          />
          <button onClick={sendEcho} disabled={!pylonConnected} className="btn btn-primary">
            Send Echo
          </button>
          <button onClick={sendPing} disabled={!pylonConnected} className="btn btn-secondary">
            Ping
          </button>
        </div>

        <div className="logs">
          <h3>Logs</h3>
          <div className="log-container">
            {logs.map((log, i) => (
              <div key={i} className={`log-entry log-${log.type}`}>
                <span className="log-time">{log.timestamp}</span>
                <span className="log-text">{log.text}</span>
              </div>
            ))}
          </div>
        </div>
      </main>
    </div>
  );
}

export default App;
