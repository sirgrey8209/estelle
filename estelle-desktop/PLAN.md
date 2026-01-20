# nexus-desktop - 구현 계획

## 역할

PC 네이티브 앱 (UI)
- Pylon과 내부 통신
- 사용자 인터페이스 제공

## Phase 1 목표

- Electron 앱 기본 구조
- Pylon에 localhost WebSocket 연결
- 연결 상태 표시 UI
- 간단한 에코 테스트 UI

## 기술 스택

- Electron
- React
- ws (WebSocket)

## 폴더 구조

```
nexus-desktop/
├── PLAN.md
├── package.json
├── electron/
│   ├── main.js           # Electron 메인 프로세스
│   └── preload.js        # IPC 브릿지
└── src/
    ├── index.html
    ├── index.jsx         # React 진입점
    ├── App.jsx           # 메인 컴포넌트
    └── styles/
        └── main.css
```

## 구현 상세

### 1. Electron 메인 (electron/main.js)
```javascript
const { app, BrowserWindow } = require('electron');
const path = require('path');

function createWindow() {
  const win = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
    },
  });

  win.loadFile('src/index.html');
}

app.whenReady().then(createWindow);
```

### 2. React UI (src/App.jsx)
```jsx
function App() {
  const [connected, setConnected] = useState(false);
  const [message, setMessage] = useState('');

  return (
    <div>
      <h1>Nexus Desktop</h1>
      <div>Status: {connected ? '🟢 Connected' : '🔴 Disconnected'}</div>
      <input value={message} onChange={e => setMessage(e.target.value)} />
      <button onClick={sendMessage}>Send</button>
    </div>
  );
}
```

### 3. Pylon 연결
```javascript
// preload.js 또는 렌더러에서
const ws = new WebSocket('ws://localhost:9000');

ws.onopen = () => setConnected(true);
ws.onclose = () => setConnected(false);
ws.onmessage = (e) => console.log('From Pylon:', e.data);
```

## UI 구성 (Phase 1)

```
┌─────────────────────────────────┐
│ Nexus Desktop                   │
├─────────────────────────────────┤
│                                 │
│  Pylon: 🟢 Connected            │
│  Relay: 🟢 Connected            │
│                                 │
│  ┌─────────────────────────┐    │
│  │ Hello                   │    │
│  └─────────────────────────┘    │
│  [Send]                         │
│                                 │
│  Response: Hello                │
│                                 │
└─────────────────────────────────┘
```

## 테스트 방법

```bash
# Relay, Pylon 먼저 실행 후
npm start

# 연결 상태 확인
# Send 버튼으로 에코 테스트
```

## 다음 단계 (Phase 2)

- 메시징 UI (Slack 스타일)
- 태스크 보드 UI (Trello 스타일)
- 파일 뷰어
- 시스템 알림
- 자동 업데이트
