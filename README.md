# Nexus

올인원 태스크/프로젝트 관리 시스템

## 개요

3개 기기(집 PC, 회사 PC, 모바일)를 연결하여 어디서든 동일한 환경으로 작업할 수 있는 통합 관리 시스템

## 환경 구성

```
┌─────────────────────────────────────────────────┐
│              ☁️ nexus-relay                     │
│              (Fly.io, 443 포트)                 │
│                     │                           │
│              WSS (아웃바운드)                    │
│                     │                           │
│       ┌─────────────┼─────────────┐             │
│       ▼             ▼             ▼             │
│   💻 집 PC      🏢 회사 PC     📱 모바일         │
│   [pylon]      [pylon]       [android]        │
│   [desktop]    [desktop]                       │
│                + 태스크 DB                      │
│                + 핑 담당                        │
│                (상시 가동)                      │
└─────────────────────────────────────────────────┘
```

## 핵심 기능 (MVP)

| 기능 | 설명 |
|------|------|
| 💬 메시징 | 코드/명령 전달 (Slack 대체) |
| 📋 태스크 보드 | 보드/리스트/카드 (Trello 대체) |
| 📄 파일 뷰어 | 3기기 상호 온디맨드 스트리밍 (저장 X) |
| 📎 파일 전송 | 10MB 이하, 저장 없이 전달 |

### 파일 뷰어 지원 포맷
- 이미지 (jpg, png, gif)
- 코드 (구문 강조)
- 마크다운 (렌더링)

## 구현 컴포넌트

| # | 컴포넌트 | 역할 | 기술 스택 |
|---|----------|------|-----------|
| 1 | nexus-relay | 중계 서버 (Fly.io) | Node.js + ws |
| 2 | nexus-pylon | PC 백그라운드 상주 + MCP | Node.js + ws + MCP SDK |
| 3 | nexus-desktop | PC 네이티브 앱 (UI) | Electron + React |
| 4 | nexus-android | 안드로이드 앱 | Kotlin + Jetpack Compose |

## 빠른 시작

### 1. 의존성 설치

```bash
# Relay
cd nexus-relay && npm install

# Pylon
cd nexus-pylon && npm install

# Desktop
cd nexus-desktop && npm install
```

### 2. 실행 (로컬 테스트)

```bash
# 터미널 1: Relay 실행
cd nexus-relay && npm start
# → ws://localhost:8080 에서 실행

# 터미널 2: Pylon 실행
cd nexus-pylon && npm start
# → Relay 연결 + localhost:9000 에서 Desktop 대기

# 터미널 3: Desktop 실행
cd nexus-desktop && npm start
# → Electron 앱 실행
```

### 3. Android

Android Studio에서 `nexus-android` 폴더를 열고 빌드/실행

## 컴포넌트별 상세

### 1. nexus-relay (중계 서버)

```
nexus-relay/
├── src/index.js      # WebSocket 서버
├── package.json
├── Dockerfile        # 컨테이너 빌드
└── fly.toml          # Fly.io 배포 설정
```

**기능:**
- WebSocket 허브 (기기 연결 관리)
- 메시지 라우팅 (기기 간 전달)
- 연결 상태 관리
- Echo/Ping 응답

**환경 변수:**
```
PORT=8080
```

### 2. nexus-pylon (PC 백그라운드)

```
nexus-pylon/
├── src/
│   ├── index.js        # 메인 진입점
│   ├── relayClient.js  # Relay 연결
│   ├── localServer.js  # Desktop 내부 통신
│   ├── mcpServer.js    # MCP 서버
│   └── mcp.js          # MCP 진입점
├── package.json
└── mcp-config.json     # Claude Code MCP 설정
```

**기능:**
- 중계 서버 WSS 연결 유지
- Desktop과 localhost WebSocket 통신
- MCP 서버 (Claude Code 연동)

**환경 변수:**
```
RELAY_URL=ws://localhost:8080
LOCAL_PORT=9000
DEVICE_ID=home-pc
```

**MCP 도구:**
| 도구 | 설명 |
|------|------|
| `nexus_status` | 연결 상태 확인 |
| `nexus_send` | 메시지 전송 |
| `nexus_echo` | Echo 테스트 |
| `nexus_desktop_notify` | Desktop 알림 |

### 3. nexus-desktop (PC 앱)

```
nexus-desktop/
├── electron/
│   ├── main.js       # Electron 메인 프로세스
│   └── preload.js    # IPC 브릿지
├── src/
│   ├── main.jsx      # React 진입점
│   ├── App.jsx       # 메인 컴포넌트
│   └── styles/main.css
├── index.html
├── vite.config.js
└── package.json
```

**기능:**
- Pylon과 내부 통신
- 연결 상태 UI
- Echo/Ping 테스트 UI

### 4. nexus-android (안드로이드 앱)

```
nexus-android/
├── app/src/main/
│   ├── java/com/nexus/android/
│   │   ├── MainActivity.kt    # 메인 액티비티
│   │   ├── MainViewModel.kt   # ViewModel
│   │   ├── RelayClient.kt     # WebSocket 클라이언트
│   │   └── ui/theme/Theme.kt  # 테마
│   ├── res/values/
│   └── AndroidManifest.xml
├── build.gradle.kts
└── settings.gradle.kts
```

**기능:**
- Relay 직접 연결
- 연결 상태 UI
- Echo/Ping 테스트 UI

## 통신 구조

### PC 내부

```
┌─────────────────────────────────────────────────┐
│                    PC                           │
├─────────────────────────────────────────────────┤
│                                                 │
│  [Claude Code]                                  │
│       │ (MCP)                                   │
│       ▼                                         │
│  [nexus-pylon]          [nexus-desktop]        │
│   ├─ Relay 연결          ├─ Pylon 연결          │
│   ├─ 파일 접근            ├─ UI                 │
│   └─ 태스크 DB            └─ 알림               │
│         │                       │               │
│         └───── localhost:9000 ──┘               │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 전체

```
┌─────────────────────────────────────────────────┐
│              ☁️ nexus-relay                     │
│              (Fly.io, 443)                     │
│                     │                           │
│       ┌─────────────┼─────────────┐             │
│       ▼             ▼             ▼             │
│   💻 집 PC      🏢 회사 PC     📱 Android       │
│   [pylon]      [pylon]       [app]            │
│   [desktop]    [desktop]                       │
└─────────────────────────────────────────────────┘
```

- 모든 기기는 **443 아웃바운드**로 Relay 연결
- 회사 보안 정책 우회 X (정상 HTTPS 트래픽)
- 파일은 저장 없이 스트리밍만 (보안)
- 인바운드/포트포워딩 필요 없음

## Claude Code MCP 설정

`~/.claude/mcp.json`에 추가:

```json
{
  "mcpServers": {
    "nexus-pylon": {
      "command": "node",
      "args": ["src/mcp.js"],
      "cwd": "C:\WorkSpace\nexus\nexus-pylon",
      "env": {
        "RELAY_URL": "ws://localhost:8080",
        "LOCAL_PORT": "9000",
        "DEVICE_ID": "home-pc"
      }
    }
  }
}
```

## 배포

### Fly.io 설정 (최초 1회)

```bash
# 1. Fly.io CLI 설치
# Windows: scoop install flyctl
# Mac: brew install flyctl

# 2. 로그인
fly auth login

# 3. 앱 생성 및 배포
cd nexus-relay
fly launch
fly deploy
```

## 기술 스택

| 구성 | 기술 |
|------|------|
| 백엔드 | Node.js |
| DB | JSON 파일 기반 (추후 마이그레이션 가능) |
| 통신 | WebSocket (WSS, 443) |
| PC 앱 | Electron + React |
| 모바일 | Kotlin + Jetpack Compose |
| 중계 서버 | Fly.io (무료 → 필요시 유료) |
| 인증 | IP + MAC 화이트리스트 (Phase 2) |

## 프로젝트 구조

```
nexus/
├── README.md           # 이 문서
├── PLAN.md             # 구현 계획
├── nexus-relay/        # 중계 서버
├── nexus-pylon/        # PC 백그라운드 + MCP
├── nexus-desktop/      # PC 앱
└── nexus-android/      # 안드로이드 앱
```

## Phase 로드맵

### Phase 1 (현재) ✅
- [x] 기본 연결 구조
- [x] Echo/Ping 테스트
- [x] MCP 기본 도구

### Phase 2 (예정)
- [ ] IP/MAC 인증
- [ ] 메시징 기능
- [ ] 태스크 보드
- [ ] 파일 뷰어/전송

### Phase 3 (예정)
- [ ] 오프라인 큐
- [ ] 푸시 알림
- [ ] 시스템 트레이
- [ ] 자동 업데이트
