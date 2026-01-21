import React, { useState, useEffect, useRef, useCallback } from 'react';

const PYLON_URL = 'ws://localhost:9000';
const LOCAL_VERSION = '1.0.0';

function App() {
  const [connected, setConnected] = useState(false);
  const [relayConnected, setRelayConnected] = useState(false);
  const [logs, setLogs] = useState([]);

  // 디바이스/데스크 상태
  const [pylonDesks, setPylonDesks] = useState(new Map()); // deviceId -> { deviceInfo, desks }

  // Claude 상태
  const [selectedDesk, setSelectedDesk] = useState(null);
  const [claudeMessages, setClaudeMessages] = useState([]);
  const [claudeInput, setClaudeInput] = useState('');
  const [currentTextBuffer, setCurrentTextBuffer] = useState('');
  const [pendingPermission, setPendingPermission] = useState(null);
  const [pendingQuestion, setPendingQuestion] = useState(null);
  const [claudeState, setClaudeState] = useState('idle');
  const [isThinking, setIsThinking] = useState(false);
  const [workStartTime, setWorkStartTime] = useState(null);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);

  // 데스크별 메시지 저장소
  const deskMessagesRef = useRef(new Map()); // deskId -> messages[]
  const deskQuestionsRef = useRef(new Map()); // deskId -> pendingQuestion

  // 모달 상태
  const [showNewDeskModal, setShowNewDeskModal] = useState(false);
  const [newDeskTarget, setNewDeskTarget] = useState(null); // { deviceId }
  const [newDeskName, setNewDeskName] = useState('');
  const [newDeskDir, setNewDeskDir] = useState('C:\\Workspace');

  const wsRef = useRef(null);
  const isCleaningUp = useRef(false);
  const claudeEndRef = useRef(null);

  const addLog = useCallback((text, type = 'info') => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prev => [...prev, { timestamp, text, type }].slice(-100));
  }, []);

  // Claude 이벤트 처리
  const handleClaudeEvent = useCallback((event) => {
    const { type } = event;

    switch (type) {
      // 세션 초기화
      case 'init':
        addLog(`Session: ${event.session_id?.substring(0, 8)}... Model: ${event.model}`, 'success');
        break;

      // 상태 업데이트 (thinking/tool/responding/idle)
      case 'stateUpdate':
        const state = event.state;
        if (state?.type === 'thinking') {
          setIsThinking(true);
        } else if (state?.type === 'responding') {
          setIsThinking(false);
        } else if (state?.type === 'tool') {
          setIsThinking(false);
        }
        break;

      // 스트리밍 텍스트
      case 'text':
        setCurrentTextBuffer(prev => prev + (event.content || ''));
        break;

      // 텍스트 완료 - 버퍼 플러시
      case 'textComplete':
        setCurrentTextBuffer(prev => {
          // 이미 버퍼에 있던 내용 무시 (textComplete가 전체 텍스트)
          return '';
        });
        setClaudeMessages(prev => [...prev, {
          role: 'assistant', type: 'text', content: event.text, timestamp: Date.now()
        }]);
        break;

      // 도구 정보 (시작)
      case 'toolInfo':
        setCurrentTextBuffer(prev => {
          if (prev) {
            setClaudeMessages(msgs => [...msgs, {
              role: 'assistant', type: 'text', content: prev, timestamp: Date.now()
            }]);
          }
          return '';
        });
        setClaudeMessages(prev => [...prev, {
          role: 'assistant',
          type: 'tool_start',
          toolName: event.toolName,
          toolInput: event.input,
          timestamp: Date.now()
        }]);
        break;

      // 도구 완료
      case 'toolComplete':
        setClaudeMessages(prev => {
          // 가장 최근의 해당 도구 찾기
          const idx = [...prev].reverse().findIndex(
            msg => msg.type === 'tool_start' && msg.toolName === event.toolName
          );
          if (idx >= 0) {
            const realIdx = prev.length - 1 - idx;
            const updated = [...prev];
            updated[realIdx] = {
              ...updated[realIdx],
              type: 'tool_complete',
              success: event.success,
              output: event.result,
              error: event.error
            };
            return updated;
          }
          return prev;
        });
        break;

      // 권한 요청
      case 'permission_request':
        setCurrentTextBuffer(prev => {
          if (prev) {
            setClaudeMessages(msgs => [...msgs, {
              role: 'assistant', type: 'text', content: prev, timestamp: Date.now()
            }]);
          }
          return '';
        });
        setPendingPermission({
          toolName: event.toolName,
          toolInput: event.toolInput,
          toolUseId: event.toolUseId
        });
        setClaudeState('permission');
        break;

      // 질문
      case 'askQuestion':
        setCurrentTextBuffer(prev => {
          if (prev) {
            setClaudeMessages(msgs => [...msgs, {
              role: 'assistant', type: 'text', content: prev, timestamp: Date.now()
            }]);
          }
          return '';
        });
        if (event.questions && event.questions.length > 0) {
          const q = event.questions[0];
          setPendingQuestion({
            question: q.question,
            header: q.header,
            options: q.options?.map(opt => opt.label) || [],
            toolUseId: event.toolUseId
          });
        }
        break;

      // 상태 (idle/working/permission)
      case 'state':
        setClaudeState(event.state);
        if (event.state === 'idle') {
          setCurrentTextBuffer(prev => {
            if (prev) {
              setClaudeMessages(msgs => [...msgs, {
                role: 'assistant', type: 'text', content: prev, timestamp: Date.now()
              }]);
            }
            return '';
          });
          setIsThinking(false);
        }
        break;

      // 결과 (토큰/비용/시간) - 메시지에 영구 기록
      case 'result':
        setClaudeMessages(prev => [...prev, {
          role: 'system',
          type: 'result',
          duration: event.duration_ms,
          inputTokens: event.usage?.inputTokens || 0,
          outputTokens: event.usage?.outputTokens || 0,
          cacheReadTokens: event.usage?.cacheReadInputTokens || 0,
          timestamp: Date.now()
        }]);
        setWorkStartTime(null);
        setIsThinking(false);
        break;

      // 에러
      case 'error':
        setClaudeMessages(prev => [...prev, {
          role: 'system', type: 'error', content: event.error, timestamp: Date.now()
        }]);
        setClaudeState('idle');
        setIsThinking(false);
        break;

      default:
        // 알 수 없는 이벤트 무시 (로그만)
        console.log(`Unknown claude event: ${type}`, event);
    }
  }, [addLog]);

  // WebSocket 메시지 핸들러 (Pylon에서 오는 메시지)
  const handleMessage = useCallback((data) => {
    const { type, payload } = data;

    switch (type) {
      case 'connected':
        addLog(`Connected to Pylon: ${data.message || ''}`, 'success');
        setRelayConnected(data.relayStatus || false);
        break;

      case 'relay_status':
        setRelayConnected(data.connected || false);
        addLog(`Relay: ${data.connected ? 'connected' : 'disconnected'}`, data.connected ? 'success' : 'error');
        break;

      case 'desk_list_result':
        // Pylon에서 온 데스크 목록
        if (payload?.deviceId !== undefined) {
          setPylonDesks(prev => {
            const next = new Map(prev);
            next.set(payload.deviceId, {
              deviceInfo: payload.deviceInfo,
              desks: payload.desks || []
            });
            return next;
          });
        }
        break;

      case 'desk_status':
        // 데스크 상태 업데이트
        if (payload?.deviceId !== undefined && payload?.deskId) {
          setPylonDesks(prev => {
            const next = new Map(prev);
            const pylon = next.get(payload.deviceId);
            if (pylon) {
              const desks = pylon.desks?.map(d =>
                d.deskId === payload.deskId
                  ? { ...d, status: payload.status, isActive: payload.isActive }
                  : d
              );
              next.set(payload.deviceId, { ...pylon, desks });
            }
            return next;
          });
        }
        break;

      case 'claude_event':
        if (payload?.event) {
          handleClaudeEvent(payload.event);
        }
        break;

      case 'message_history':
        // 데스크별 메시지 히스토리 저장
        if (payload?.deskId && payload?.messages) {
          deskMessagesRef.current.set(payload.deskId, payload.messages);
          addLog(`Loaded ${payload.messages.length} messages for ${payload.deskId.substring(0, 12)}...`, 'info');
          // 현재 선택된 데스크라면 바로 표시
          if (selectedDesk?.deskId === payload.deskId) {
            setClaudeMessages(payload.messages);
          }
        }
        break;

      case 'error':
        addLog(`Error: ${payload?.error}`, 'error');
        break;

      default:
        addLog(`Received: ${type}`, 'message');
    }
  }, [addLog, handleClaudeEvent, selectedDesk]);

  // Pylon 연결
  const connectToPylon = useCallback(() => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) return;

    addLog('Connecting to Pylon...', 'info');
    const ws = new WebSocket(PYLON_URL);

    ws.onopen = () => {
      setConnected(true);
      addLog('Connected to Pylon', 'success');
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        handleMessage(data);
      } catch (err) {
        addLog(`Parse error: ${event.data}`, 'error');
      }
    };

    ws.onclose = () => {
      setConnected(false);
      setRelayConnected(false);
      setPylonDesks(new Map());
      addLog('Disconnected from Pylon', 'error');

      if (!isCleaningUp.current) {
        setTimeout(connectToPylon, 3000);
      }
    };

    ws.onerror = () => {
      addLog('Pylon connection error', 'error');
    };

    wsRef.current = ws;
  }, [addLog, handleMessage]);

  // 초기화
  useEffect(() => {
    isCleaningUp.current = false;
    connectToPylon();
    return () => { isCleaningUp.current = true; };
  }, [connectToPylon]);

  // Claude 스크롤
  useEffect(() => {
    claudeEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [claudeMessages, currentTextBuffer]);

  // 작업 중 경과시간 타이머
  useEffect(() => {
    if (!workStartTime) {
      setElapsedSeconds(0);
      return;
    }
    const interval = setInterval(() => {
      setElapsedSeconds(Math.floor((Date.now() - workStartTime) / 1000));
    }, 1000);
    return () => clearInterval(interval);
  }, [workStartTime]);

  // 메시지를 데스크별로 저장 (실시간)
  useEffect(() => {
    if (selectedDesk && claudeMessages.length > 0) {
      deskMessagesRef.current.set(selectedDesk.deskId, claudeMessages);
    }
  }, [selectedDesk, claudeMessages]);

  // 메시지 전송 함수들 (Pylon 경유)
  const send = (message) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(message));
    }
  };

  const sendClaudeMessage = () => {
    if (!claudeInput.trim() || !selectedDesk) return;

    setClaudeMessages(prev => [...prev, {
      role: 'user', type: 'text', content: claudeInput, timestamp: Date.now()
    }]);

    send({
      type: 'claude_send',
      to: { deviceId: selectedDesk.deviceId, deviceType: 'pylon' },
      payload: { deskId: selectedDesk.deskId, message: claudeInput }
    });

    setClaudeInput('');
    setClaudeState('working');
    setIsThinking(true);
    setWorkStartTime(Date.now());
  };

  const respondPermission = (decision) => {
    if (!pendingPermission || !selectedDesk) return;

    send({
      type: 'claude_permission',
      to: { deviceId: selectedDesk.deviceId, deviceType: 'pylon' },
      payload: {
        deskId: selectedDesk.deskId,
        toolUseId: pendingPermission.toolUseId,
        decision
      }
    });

    setPendingPermission(null);
    setClaudeState('working');
  };

  const respondQuestion = (answer) => {
    if (!pendingQuestion || !selectedDesk) return;

    send({
      type: 'claude_answer',
      to: { deviceId: selectedDesk.deviceId, deviceType: 'pylon' },
      payload: {
        deskId: selectedDesk.deskId,
        toolUseId: pendingQuestion.toolUseId,
        answer
      }
    });

    setPendingQuestion(null);
    deskQuestionsRef.current.delete(selectedDesk.deskId);
    setClaudeState('working');
  };

  const sendClaudeControl = (action) => {
    if (!selectedDesk) return;

    send({
      type: 'claude_control',
      to: { deviceId: selectedDesk.deviceId, deviceType: 'pylon' },
      payload: { deskId: selectedDesk.deskId, action }
    });

    if (action === 'new_session') {
      setClaudeMessages([]);
      setCurrentTextBuffer('');
    }
  };

  const selectDesk = (desk) => {
    // 현재 데스크의 메시지와 질문 저장
    if (selectedDesk) {
      deskMessagesRef.current.set(selectedDesk.deskId, claudeMessages);
      if (pendingQuestion) {
        deskQuestionsRef.current.set(selectedDesk.deskId, pendingQuestion);
      } else {
        deskQuestionsRef.current.delete(selectedDesk.deskId);
      }
    }

    // 새 데스크 선택
    setSelectedDesk(desk);

    // 저장된 메시지와 질문 복원
    const savedMessages = deskMessagesRef.current.get(desk.deskId) || [];
    const savedQuestion = deskQuestionsRef.current.get(desk.deskId) || null;
    setClaudeMessages(savedMessages);
    setPendingQuestion(savedQuestion);
    setCurrentTextBuffer('');
    setClaudeState(savedQuestion ? 'question' : 'idle');
    setIsThinking(false);
    setWorkStartTime(null);
  };

  const handleClaudeKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendClaudeMessage();
    }
  };

  // 새 데스크 생성
  const openNewDeskModal = (deviceId) => {
    setNewDeskTarget({ deviceId });
    setNewDeskName('');
    setNewDeskDir('C:\\Workspace');
    setShowNewDeskModal(true);
  };

  const createNewDesk = () => {
    if (!newDeskName.trim() || !newDeskTarget) return;

    send({
      type: 'desk_create',
      to: { deviceId: newDeskTarget.deviceId, deviceType: 'pylon' },
      payload: { name: newDeskName.trim(), workingDir: newDeskDir.trim() }
    });

    setShowNewDeskModal(false);
    setNewDeskTarget(null);
    setNewDeskName('');
  };

  // Pylon 그룹별 데스크 목록
  const pylonGroups = Array.from(pylonDesks.entries()).map(([deviceId, data]) => ({
    deviceId,
    deviceInfo: data.deviceInfo,
    desks: data.desks || []
  }));

  return (
    <div className="app">
      {/* 권한 요청 모달 */}
      {pendingPermission && (
        <div className="modal-overlay">
          <div className="modal permission-modal">
            <h2>Permission Request</h2>
            <div className="permission-tool">
              <span className="tool-name">{pendingPermission.toolName}</span>
            </div>
            <pre className="permission-input">
              {JSON.stringify(pendingPermission.toolInput, null, 2)}
            </pre>
            <div className="modal-buttons">
              <button className="btn btn-success" onClick={() => respondPermission('allow')}>Allow</button>
              <button className="btn btn-warning" onClick={() => respondPermission('allowAll')}>Allow All</button>
              <button className="btn btn-danger" onClick={() => respondPermission('deny')}>Deny</button>
            </div>
          </div>
        </div>
      )}


      {/* 새 데스크 모달 */}
      {showNewDeskModal && (
        <div className="modal-overlay" onClick={() => setShowNewDeskModal(false)}>
          <div className="modal new-desk-modal" onClick={e => e.stopPropagation()}>
            <h2>New Desk</h2>
            <div className="form-group">
              <label>Name</label>
              <input
                type="text"
                className="form-input"
                placeholder="Project name..."
                value={newDeskName}
                onChange={(e) => setNewDeskName(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && createNewDesk()}
                autoFocus
              />
            </div>
            <div className="form-group">
              <label>Working Directory</label>
              <input
                type="text"
                className="form-input"
                placeholder="C:\Workspace\..."
                value={newDeskDir}
                onChange={(e) => setNewDeskDir(e.target.value)}
              />
            </div>
            <div className="modal-buttons">
              <button className="btn btn-secondary" onClick={() => setShowNewDeskModal(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={createNewDesk} disabled={!newDeskName.trim()}>Create</button>
            </div>
          </div>
        </div>
      )}

      <header className="header">
        <h1>Estelle Desktop <span className="version">v{LOCAL_VERSION}</span></h1>
        <div className="status-bar">
          {!connected ? (
            <span className="status disconnected">Pylon Off</span>
          ) : !relayConnected ? (
            <span className="status relay-off">Relay Off</span>
          ) : (
            <div className="status-connected">
              <span className="status connected">Connected</span>
              <div className="connected-devices">
                {pylonGroups.map(({ deviceId, deviceInfo }) => (
                  <span key={deviceId} className="device-icon" title={deviceInfo?.name || `Device ${deviceId}`}>
                    {deviceInfo?.icon || '💻'}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      </header>

      <div className="main-layout">
        {/* 좌측 사이드바 */}
        <aside className="sidebar">
          <div className="sidebar-header">
            <h3>Pylons</h3>
          </div>
          <div className="sidebar-content">
            {pylonGroups.length === 0 ? (
              <div className="no-pylons">No Pylons connected</div>
            ) : (
              pylonGroups.map(({ deviceId, deviceInfo, desks }) => (
                <div key={deviceId} className="pylon-group">
                  <div className="pylon-header">
                    <span className="pylon-icon">{deviceInfo?.icon || '💻'}</span>
                    <span className="pylon-name">{deviceInfo?.name || `Device ${deviceId}`}</span>
                    <button
                      className="btn-icon"
                      onClick={() => openNewDeskModal(deviceId)}
                      title="New Desk"
                    >
                      +
                    </button>
                  </div>
                  <div className="desk-list">
                    {desks.length === 0 ? (
                      <div className="no-desks">No desks</div>
                    ) : (
                      desks.map((desk) => (
                        <button
                          key={desk.deskId}
                          className={`desk-item ${selectedDesk?.deskId === desk.deskId && selectedDesk?.deviceId === deviceId ? 'selected' : ''} ${desk.status === 'working' ? 'working' : ''}`}
                          onClick={() => selectDesk({ ...desk, deviceId, deviceInfo })}
                        >
                          <span className="desk-name">{desk.name}</span>
                          {desk.status === 'working' && <span className="desk-status-dot"></span>}
                        </button>
                      ))
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </aside>

        {/* 우측 대화창 */}
        <main className="chat-area">
          {selectedDesk ? (
            <>
              {/* 대화창 헤더 */}
              <div className="chat-header">
                <div className="chat-header-left">
                  <span className="chat-desk-icon">{selectedDesk.deviceInfo?.icon || '💻'}</span>
                  <span className="chat-desk-name">{selectedDesk.name}</span>
                  <span className={`chat-state ${claudeState}`}>{claudeState}</span>
                </div>
                <div className="chat-header-right">
                  <button
                    className="btn btn-small"
                    onClick={() => sendClaudeControl('stop')}
                    disabled={claudeState !== 'working'}
                  >
                    Stop
                  </button>
                  <button
                    className="btn btn-small"
                    onClick={() => sendClaudeControl('new_session')}
                  >
                    New Session
                  </button>
                </div>
              </div>

              {/* 메시지 영역 */}
              <div className="claude-messages">
                {claudeMessages.length === 0 && !currentTextBuffer ? (
                  <div className="no-messages">
                    <p>세션이 없습니다.</p>
                    <p className="hint">메시지를 입력하시면 자동으로 새 세션이 시작됩니다.</p>
                  </div>
                ) : (
                  <>
                    {claudeMessages.map((msg, i) => (
                      <ClaudeMessageBubble key={i} message={msg} />
                    ))}
                    {currentTextBuffer && (
                      <div className="claude-message assistant">
                        <div className="message-bubble streaming">
                          <pre className="message-text">{currentTextBuffer}</pre>
                          <span className="streaming-indicator">●</span>
                        </div>
                      </div>
                    )}
                    {/* 작업 중 상태 표시 */}
                    {workStartTime && (
                      <div className="working-status">
                        <span className="working-dot"></span>
                        <span className="working-time">{elapsedSeconds}s</span>
                      </div>
                    )}
                  </>
                )}
                <div ref={claudeEndRef} />
              </div>

              {/* 입력창 또는 선택지 */}
              {pendingQuestion ? (
                <div className="question-input-area">
                  <div className="question-header">
                    <span className="question-badge">{pendingQuestion.header || 'Question'}</span>
                    <span className="question-text">{pendingQuestion.question}</span>
                  </div>
                  <div className="question-options">
                    {pendingQuestion.options?.map((opt, i) => (
                      <button key={i} className="btn btn-option" onClick={() => respondQuestion(opt)}>
                        {opt}
                      </button>
                    ))}
                  </div>
                  <div className="question-custom">
                    <input
                      type="text"
                      className="question-custom-input"
                      placeholder="Or type custom answer..."
                      onKeyPress={(e) => {
                        if (e.key === 'Enter' && e.target.value.trim()) {
                          respondQuestion(e.target.value.trim());
                          e.target.value = '';
                        }
                      }}
                    />
                  </div>
                </div>
              ) : (
                <div className="claude-input-container">
                  <textarea
                    value={claudeInput}
                    onChange={(e) => setClaudeInput(e.target.value)}
                    onKeyPress={handleClaudeKeyPress}
                    placeholder="Type a message..."
                    className="claude-input"
                    disabled={claudeState === 'working'}
                    rows={1}
                  />
                  <button
                    onClick={sendClaudeMessage}
                    disabled={!claudeInput.trim() || claudeState === 'working'}
                    className="btn btn-primary btn-send"
                  >
                    Send
                  </button>
                </div>
              )}
            </>
          ) : (
            <div className="no-desk-selected">
              <p>좌측에서 데스크를 선택하거나 생성해주세요.</p>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

/**
 * Tool Input을 해석하여 description과 command 반환
 */
function parseToolInput(toolName, input) {
  if (!input) return { desc: '', cmd: '' };

  switch (toolName) {
    case 'Bash':
      return {
        desc: input.description || '',
        cmd: input.command || ''
      };
    case 'Read':
      return {
        desc: 'Read file',
        cmd: input.file_path || ''
      };
    case 'Edit':
      return {
        desc: 'Edit file',
        cmd: input.file_path || ''
      };
    case 'Write':
      return {
        desc: 'Write file',
        cmd: input.file_path || ''
      };
    case 'Glob':
      return {
        desc: input.path ? `Search in ${input.path}` : 'Search files',
        cmd: input.pattern || ''
      };
    case 'Grep':
      return {
        desc: input.path ? `Search in ${input.path}` : 'Search content',
        cmd: input.pattern || ''
      };
    case 'WebFetch':
      return {
        desc: 'Fetch URL',
        cmd: input.url || ''
      };
    case 'WebSearch':
      return {
        desc: 'Web search',
        cmd: input.query || ''
      };
    case 'Task':
      return {
        desc: input.description || 'Run task',
        cmd: (input.prompt || '').substring(0, 100) + (input.prompt?.length > 100 ? '...' : '')
      };
    case 'TodoWrite':
      return {
        desc: 'Update todos',
        cmd: `${input.todos?.length || 0} items`
      };
    default:
      // 기타 도구는 첫 번째 문자열 값 사용
      const firstVal = Object.values(input).find(v => typeof v === 'string');
      return {
        desc: toolName,
        cmd: firstVal ? String(firstVal).substring(0, 80) : ''
      };
  }
}

/**
 * Output 마지막 n줄 가져오기
 */
function getLastLines(text, n = 3) {
  if (!text) return '';
  const lines = text.split('\n').filter(l => l.trim());
  return lines.slice(-n).join('\n');
}

function ClaudeMessageBubble({ message }) {
  const { role, type, content, toolName, toolInput, output, success, error } = message;
  const [expanded, setExpanded] = React.useState(false);

  // 결과 정보 (영구 기록)
  if (type === 'result') {
    const totalTokens = (message.inputTokens || 0) + (message.outputTokens || 0);
    const durationSec = ((message.duration || 0) / 1000).toFixed(1);
    return (
      <div className="result-record">
        <span className="result-time">{durationSec}<span className="result-unit">s</span></span>
        <span className="result-sep">·</span>
        <span className="result-tokens">{totalTokens.toLocaleString()}<span className="result-unit"> tokens</span></span>
      </div>
    );
  }

  if (type === 'error') {
    return (
      <div className="claude-message system">
        <div className="message-bubble error">
          <span className="error-icon">⚠️</span>
          <span className="error-text">{content}</span>
        </div>
      </div>
    );
  }

  if (role === 'user') {
    return (
      <div className="claude-message user">
        <div className="message-bubble user-bubble">
          <pre className="message-text">{content}</pre>
        </div>
      </div>
    );
  }

  if (type === 'tool_start' || type === 'tool_complete') {
    const isComplete = type === 'tool_complete';
    const isSuccess = success !== false;
    const { desc, cmd } = parseToolInput(toolName, toolInput);
    const hasOutput = output && output.trim();

    return (
      <div className="claude-message assistant">
        <div
          className={`tool-card ${isComplete ? (isSuccess ? 'success' : 'failed') : 'running'}`}
          onClick={() => hasOutput && setExpanded(!expanded)}
          style={{ cursor: hasOutput ? 'pointer' : 'default' }}
        >
          <div className="tool-header">
            <span className="tool-status">
              {isComplete ? (isSuccess ? '✓' : '✗') : '⋯'}
            </span>
            <span className="tool-name">{toolName}</span>
            {desc && <span className="tool-desc">{desc}</span>}
          </div>
          {cmd && (
            <div className="tool-cmd">
              <code>{cmd}</code>
            </div>
          )}
          {/* 진행 중일 때: 마지막 몇 줄만 표시 */}
          {!isComplete && hasOutput && !expanded && (
            <div className="tool-preview">
              <pre>{getLastLines(output, 3)}</pre>
            </div>
          )}
          {/* 확장 시 또는 진행 중 확장 시: 전체 출력 */}
          {expanded && hasOutput && (
            <div className="tool-output-full">
              <pre>{output}</pre>
            </div>
          )}
          {/* 완료 후 에러 표시 */}
          {isComplete && error && (
            <div className="tool-error">
              <pre>{error}</pre>
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="claude-message assistant">
      <div className="message-bubble assistant-bubble">
        <pre className="message-text">{content}</pre>
      </div>
    </div>
  );
}

export default App;
