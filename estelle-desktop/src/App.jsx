import React, { useState, useEffect, useRef, useCallback } from 'react';

const RELAY_URL = 'wss://estelle-relay.fly.dev';
const LOCAL_VERSION = '1.0.0';
// Desktop 전용 동적 deviceId (100 이상)
const DESKTOP_DEVICE_ID = 100 + Math.floor(Math.random() * 100);

function App() {
  const [connected, setConnected] = useState(false);
  const [logs, setLogs] = useState([]);

  // 디바이스/데스크 상태
  const [pylonDesks, setPylonDesks] = useState(new Map()); // deviceId -> { deviceInfo, desks }

  // Claude 상태
  const [selectedDesk, setSelectedDesk] = useState(null);
  const [claudeMessages, setClaudeMessages] = useState([]);
  const [claudeInput, setClaudeInput] = useState('');
  const [currentTextBuffer, setCurrentTextBuffer] = useState('');
  // 통합 요청 큐: [{ type: 'question'|'permission', ... }]
  const [pendingRequests, setPendingRequests] = useState([]);
  const [claudeState, setClaudeState] = useState('idle');
  const [isThinking, setIsThinking] = useState(false);
  const [workStartTime, setWorkStartTime] = useState(null);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);

  // 데스크별 저장소
  const deskMessagesRef = useRef(new Map()); // deskId -> messages[]
  const deskRequestsRef = useRef(new Map()); // deskId -> pendingRequests[]

  // 모달 상태
  const [showNewDeskModal, setShowNewDeskModal] = useState(false);
  const [newDeskTarget, setNewDeskTarget] = useState(null); // { deviceId }
  const [newDeskName, setNewDeskName] = useState('');
  const [newDeskDir, setNewDeskDir] = useState('C:\\Workspace');

  const wsRef = useRef(null);        // Relay 연결
  const isAuthenticated = useRef(false);
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

      // 권한 요청 → 요청 큐에 추가
      case 'permission_request':
        setCurrentTextBuffer(prev => {
          if (prev) {
            setClaudeMessages(msgs => [...msgs, {
              role: 'assistant', type: 'text', content: prev, timestamp: Date.now()
            }]);
          }
          return '';
        });
        setPendingRequests(prev => [...prev, {
          type: 'permission',
          toolName: event.toolName,
          toolInput: event.toolInput,
          toolUseId: event.toolUseId
        }]);
        setClaudeState('permission');
        break;

      // 질문 (멀티 선택지 지원) → 요청 큐에 추가
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
          setPendingRequests(prev => [...prev, {
            type: 'question',
            questions: event.questions.map(q => ({
              question: q.question,
              header: q.header,
              options: q.options?.map(opt => opt.label) || [],
              multiSelect: q.multiSelect || false
            })),
            answers: {},
            toolUseId: event.toolUseId
          }]);
        }
        setClaudeState('permission');
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

  // WebSocket 메시지 핸들러 (Relay 전용)
  const handleMessage = useCallback((data) => {
    const { type, payload } = data;

    switch (type) {
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
        if (payload?.event && payload?.deskId) {
          // 현재 선택된 데스크의 이벤트만 화면에 표시
          if (selectedDesk?.deskId === payload.deskId) {
            handleClaudeEvent(payload.event);
          } else {
            // 다른 데스크의 이벤트는 저장만 (textComplete, error 등)
            const event = payload.event;
            if (event.type === 'textComplete' || event.type === 'error' || event.type === 'result') {
              const saved = deskMessagesRef.current.get(payload.deskId) || [];
              if (event.type === 'textComplete') {
                saved.push({ role: 'assistant', type: 'text', content: event.text, timestamp: Date.now() });
              } else if (event.type === 'error') {
                saved.push({ role: 'system', type: 'error', content: event.error, timestamp: Date.now() });
              }
              deskMessagesRef.current.set(payload.deskId, saved);
            }
            // 다른 데스크의 요청은 큐에 저장
            if (event.type === 'askQuestion' || event.type === 'permission_request') {
              const savedRequests = deskRequestsRef.current.get(payload.deskId) || [];
              if (event.type === 'askQuestion') {
                savedRequests.push({
                  type: 'question',
                  questions: event.questions.map(q => ({
                    question: q.question,
                    header: q.header,
                    options: q.options?.map(opt => opt.label) || [],
                    multiSelect: q.multiSelect || false
                  })),
                  answers: {},
                  toolUseId: event.toolUseId
                });
              } else {
                savedRequests.push({
                  type: 'permission',
                  toolName: event.toolName,
                  toolInput: event.toolInput,
                  toolUseId: event.toolUseId
                });
              }
              deskRequestsRef.current.set(payload.deskId, savedRequests);
            }
          }
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

  // Relay 연결 (모든 Pylon 통신용)
  const connectToRelay = useCallback(() => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) return;

    addLog('Connecting to Relay...', 'info');
    const ws = new WebSocket(RELAY_URL);

    ws.onopen = () => {
      addLog('Connected to Relay, authenticating...', 'info');
      // 인증 요청 (Desktop 전용 동적 ID)
      ws.send(JSON.stringify({
        type: 'auth',
        payload: { deviceId: DESKTOP_DEVICE_ID, deviceType: 'desktop' }
      }));
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);

        // 인증 결과 처리
        if (data.type === 'auth_result') {
          if (data.payload?.success) {
            isAuthenticated.current = true;
            setConnected(true);
            addLog(`Relay authenticated as ${data.payload.device?.name}`, 'success');
            // 데스크 목록 요청 (브로드캐스트)
            ws.send(JSON.stringify({
              type: 'desk_list',
              broadcast: 'pylons'
            }));
          } else {
            addLog(`Relay auth failed: ${data.payload?.error}`, 'error');
          }
          return;
        }

        handleMessage(data);
      } catch (err) {
        addLog(`Relay parse error: ${event.data}`, 'error');
      }
    };

    ws.onclose = () => {
      isAuthenticated.current = false;
      setConnected(false);
      setPylonDesks(new Map());
      addLog('Disconnected from Relay', 'error');

      if (!isCleaningUp.current) {
        setTimeout(connectToRelay, 5000);
      }
    };

    ws.onerror = () => {
      addLog('Relay connection error', 'error');
    };

    wsRef.current = ws;
  }, [addLog, handleMessage]);

  // 초기화
  useEffect(() => {
    isCleaningUp.current = false;
    connectToRelay();
    return () => {
      isCleaningUp.current = true;
      wsRef.current?.close();
    };
  }, [connectToRelay]);

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

  // 메시지 전송 (Relay 경유)
  const send = (message) => {
    if (wsRef.current?.readyState === WebSocket.OPEN && isAuthenticated.current) {
      wsRef.current.send(JSON.stringify(message));
    } else {
      addLog('Cannot send: not connected to Relay', 'error');
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

  // 현재 처리할 요청 (큐의 첫 번째)
  const currentRequest = pendingRequests[0] || null;

  // 요청 완료 후 큐에서 제거
  const completeCurrentRequest = () => {
    setPendingRequests(prev => prev.slice(1));
    // 다음 요청이 없으면 working 상태로
    if (pendingRequests.length <= 1) {
      setClaudeState('working');
    }
  };

  // 권한 응답
  const respondPermission = (decision) => {
    if (!currentRequest || currentRequest.type !== 'permission' || !selectedDesk) return;

    // 응답 메시지 기록
    const decisionText = decision === 'allow' ? '승인됨' : '거부됨';
    setClaudeMessages(prev => [...prev, {
      role: 'user',
      type: 'response',
      responseType: 'permission',
      toolName: currentRequest.toolName,
      decision: decisionText,
      timestamp: Date.now()
    }]);

    send({
      type: 'claude_permission',
      to: { deviceId: selectedDesk.deviceId, deviceType: 'pylon' },
      payload: {
        deskId: selectedDesk.deskId,
        toolUseId: currentRequest.toolUseId,
        decision
      }
    });

    completeCurrentRequest();
  };

  // 멀티 선택지: 개별 질문에 답변 선택/변경
  const selectQuestionAnswer = (questionIndex, answer) => {
    if (!currentRequest || currentRequest.type !== 'question') return;
    setPendingRequests(prev => {
      const updated = [...prev];
      updated[0] = {
        ...updated[0],
        answers: { ...updated[0].answers, [questionIndex]: answer }
      };
      return updated;
    });
  };

  // 멀티 선택지: 모든 답변 제출
  const submitQuestionAnswers = () => {
    if (!currentRequest || currentRequest.type !== 'question' || !selectedDesk) return;

    // 답변을 배열로 변환 (질문 순서대로)
    const answersArray = currentRequest.questions.map((_, idx) =>
      currentRequest.answers[idx] || ''
    );
    const answerToSend = answersArray.length === 1 ? answersArray[0] : answersArray;

    // 응답 메시지 기록
    setClaudeMessages(prev => [...prev, {
      role: 'user',
      type: 'response',
      responseType: 'question',
      answers: answersArray,
      timestamp: Date.now()
    }]);

    send({
      type: 'claude_answer',
      to: { deviceId: selectedDesk.deviceId, deviceType: 'pylon' },
      payload: {
        deskId: selectedDesk.deskId,
        toolUseId: currentRequest.toolUseId,
        answer: answerToSend
      }
    });

    deskRequestsRef.current.delete(selectedDesk.deskId);
    completeCurrentRequest();
  };

  // 단일 질문 빠른 응답 (선택 즉시 제출)
  const respondQuestionDirect = (answer) => {
    if (!currentRequest || currentRequest.type !== 'question' || !selectedDesk) return;

    // 응답 메시지 기록
    setClaudeMessages(prev => [...prev, {
      role: 'user',
      type: 'response',
      responseType: 'question',
      answers: [answer],
      timestamp: Date.now()
    }]);

    send({
      type: 'claude_answer',
      to: { deviceId: selectedDesk.deviceId, deviceType: 'pylon' },
      payload: {
        deskId: selectedDesk.deskId,
        toolUseId: currentRequest.toolUseId,
        answer
      }
    });

    deskRequestsRef.current.delete(selectedDesk.deskId);
    completeCurrentRequest();
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
    // 현재 데스크의 메시지와 요청 저장
    if (selectedDesk) {
      deskMessagesRef.current.set(selectedDesk.deskId, claudeMessages);
      if (pendingRequests.length > 0) {
        deskRequestsRef.current.set(selectedDesk.deskId, pendingRequests);
      } else {
        deskRequestsRef.current.delete(selectedDesk.deskId);
      }
    }

    // 새 데스크 선택
    setSelectedDesk(desk);

    // 저장된 메시지와 요청 복원
    const savedMessages = deskMessagesRef.current.get(desk.deskId) || [];
    const savedRequests = deskRequestsRef.current.get(desk.deskId) || [];
    setClaudeMessages(savedMessages);
    setPendingRequests(savedRequests);
    setCurrentTextBuffer('');
    setClaudeState(savedRequests.length > 0 ? 'permission' : 'idle');
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
            <span className="status disconnected">Disconnected</span>
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

              {/* 입력창 또는 요청 응답 영역 */}
              {currentRequest ? (
                <div className="request-input-area">
                  {/* 권한 요청 */}
                  {currentRequest.type === 'permission' && (
                    <>
                      <div className="request-header">
                        <span className="request-badge permission">권한 요청</span>
                        <span className="request-tool">{currentRequest.toolName}</span>
                      </div>
                      <div className="request-options">
                        <button className="btn btn-allow" onClick={() => respondPermission('allow')}>
                          승인
                        </button>
                        <button className="btn btn-deny" onClick={() => respondPermission('deny')}>
                          거부
                        </button>
                      </div>
                    </>
                  )}

                  {/* 질문 (멀티 선택지) */}
                  {currentRequest.type === 'question' && (
                    <>
                      {currentRequest.questions.map((q, qIdx) => (
                        <div key={qIdx} className="question-item">
                          <div className="question-header">
                            <span className="question-badge">{q.header || 'Question'}</span>
                            <span className="question-text">{q.question}</span>
                          </div>
                          <div className="question-options">
                            {q.options?.map((opt, oIdx) => (
                              <button
                                key={oIdx}
                                className={`btn btn-option ${currentRequest.answers[qIdx] === opt ? 'selected' : ''}`}
                                onClick={() => {
                                  // 단일 질문이면 바로 제출, 멀티면 선택만
                                  if (currentRequest.questions.length === 1) {
                                    respondQuestionDirect(opt);
                                  } else {
                                    selectQuestionAnswer(qIdx, opt);
                                  }
                                }}
                              >
                                {opt}
                              </button>
                            ))}
                          </div>
                        </div>
                      ))}
                      {/* 멀티 질문일 때 제출 버튼 */}
                      {currentRequest.questions.length > 1 && (
                        <div className="question-submit">
                          <button
                            className="btn btn-primary"
                            onClick={submitQuestionAnswers}
                            disabled={Object.keys(currentRequest.answers).length < currentRequest.questions.length}
                          >
                            제출 ({Object.keys(currentRequest.answers).length}/{currentRequest.questions.length})
                          </button>
                        </div>
                      )}
                      {/* 커스텀 입력 (단일 질문일 때만) */}
                      {currentRequest.questions.length === 1 && (
                        <div className="question-custom">
                          <input
                            type="text"
                            className="question-custom-input"
                            placeholder="Or type custom answer..."
                            onKeyPress={(e) => {
                              if (e.key === 'Enter' && e.target.value.trim()) {
                                respondQuestionDirect(e.target.value.trim());
                                e.target.value = '';
                              }
                            }}
                          />
                        </div>
                      )}
                    </>
                  )}

                  {/* 대기 중인 요청 개수 표시 */}
                  {pendingRequests.length > 1 && (
                    <div className="pending-count">+{pendingRequests.length - 1} more</div>
                  )}
                </div>
              ) : selectedDesk?.canResume && !selectedDesk?.hasActiveSession ? (
                // 세션 재개 선택지
                <div className="request-input-area">
                  <div className="request-header">
                    <span className="request-badge session">세션 복구</span>
                    <span className="request-tool">이전 세션이 있습니다</span>
                  </div>
                  <div className="request-options">
                    <button className="btn btn-allow" onClick={() => sendClaudeControl('resume')}>
                      이어서 작업
                    </button>
                    <button className="btn btn-secondary" onClick={() => sendClaudeControl('new_session')}>
                      새로 시작
                    </button>
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

  // 응답 기록 (권한/질문)
  if (role === 'user' && type === 'response') {
    if (message.responseType === 'permission') {
      return (
        <div className="claude-message user">
          <div className="message-bubble response-bubble">
            <span className="response-tool">{message.toolName}</span>
            <span className={`response-decision ${message.decision === '승인됨' ? 'allowed' : 'denied'}`}>
              ({message.decision})
            </span>
          </div>
        </div>
      );
    }
    if (message.responseType === 'question') {
      return (
        <div className="claude-message user">
          <div className="message-bubble response-bubble">
            <span className="response-answers">{message.answers?.join(', ')}</span>
          </div>
        </div>
      );
    }
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
