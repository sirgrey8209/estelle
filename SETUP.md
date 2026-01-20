# Estelle 설치 가이드

회사/집 PC에서 Estelle 환경 설정하는 방법

## 1. 저장소 Clone

```bash
git clone https://github.com/sirgrey8209/estelle.git
cd estelle
```

## 2. 의존성 설치

```bash
# Relay
cd estelle-relay && npm install

# Pylon
cd ../estelle-pylon && npm install

# Desktop
cd ../estelle-desktop && npm install

# 루트로 복귀
cd ..
```

## 3. 환경 변수 설정

### estelle-pylon/.env

```bash
cd estelle-pylon
cp .env.example .env
```

`.env` 파일 편집:
```
RELAY_URL=ws://localhost:8080
LOCAL_PORT=9000
DEVICE_ID=office-pc
```

> **DEVICE_ID**: 집 PC는 `home-pc`, 회사 PC는 `office-pc`로 구분

## 4. 로컬 테스트 실행

터미널 3개 필요:

```bash
# 터미널 1: Relay
cd estelle-relay && npm start

# 터미널 2: Pylon
cd estelle-pylon && npm start

# 터미널 3: Desktop
cd estelle-desktop && npm start
```

연결 확인:
- Desktop 앱에서 Pylon: 🟢, Relay: 🟢 표시되면 성공

## 5. Fly.io 설정 (Relay 배포)

### 5.1 Fly.io CLI 설치

**Windows (Scoop):**
```bash
scoop install flyctl
```

**Windows (PowerShell):**
```powershell
pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"
```

**Mac:**
```bash
brew install flyctl
```

### 5.2 Fly.io 로그인

```bash
fly auth login
```
> 브라우저에서 로그인 진행

### 5.3 앱 생성 및 배포

```bash
cd estelle-relay

# 앱 생성 (최초 1회)
fly launch --name estelle-relay --region nrt --no-deploy

# 배포
fly deploy
```

> `--region nrt`: 도쿄 리전 (한국에서 가장 가까움)

### 5.4 배포 확인

```bash
fly status
```

배포된 URL 확인:
```
https://estelle-relay.fly.dev
```

### 5.5 Pylon 설정 업데이트

`estelle-pylon/.env` 수정:
```
RELAY_URL=wss://estelle-relay.fly.dev
LOCAL_PORT=9000
DEVICE_ID=office-pc
```

> `ws://` → `wss://` (HTTPS)

## 6. Claude Code MCP 설정

`~/.claude/mcp.json` 파일에 추가:

**Windows 경로:**
```json
{
  "mcpServers": {
    "estelle-pylon": {
      "command": "node",
      "args": ["src/mcp.js"],
      "cwd": "C:\\WorkSpace\\estelle\\estelle-pylon",
      "env": {
        "RELAY_URL": "wss://estelle-relay.fly.dev",
        "LOCAL_PORT": "9000",
        "DEVICE_ID": "office-pc"
      }
    }
  }
}
```

> **주의**: `cwd` 경로를 실제 clone한 위치로 수정

Claude Code 재시작 후 MCP 도구 사용 가능:
- `estelle_status`: 연결 상태 확인
- `estelle_send`: 메시지 전송
- `estelle_echo`: Echo 테스트
- `estelle_desktop_notify`: Desktop 알림

## 7. 전체 구조 확인

```
[회사 PC]
├── estelle-pylon (백그라운드 실행)
│   └── wss://estelle-relay.fly.dev 연결
├── estelle-desktop (UI 앱)
│   └── localhost:9000으로 pylon 연결
└── Claude Code
    └── MCP로 pylon 제어

        ↕ (WSS 443)

[Fly.io]
└── estelle-relay (중계 서버)

        ↕ (WSS 443)

[집 PC / 모바일]
└── 동일한 relay에 연결
```

## 문제 해결

### Pylon이 Relay에 연결 안 됨
- `.env`의 `RELAY_URL` 확인
- Fly.io 배포 상태 확인: `fly status`
- 방화벽에서 443 아웃바운드 허용 확인

### Desktop이 Pylon에 연결 안 됨
- Pylon이 실행 중인지 확인
- `LOCAL_PORT`가 9000인지 확인
- 다른 프로그램이 9000 포트 사용 중인지 확인

### MCP 도구가 안 보임
- `~/.claude/mcp.json` 경로 확인
- JSON 문법 오류 확인
- Claude Code 재시작

## 다음 단계

설치 완료 후:
1. 집 PC에서도 동일하게 설정 (DEVICE_ID만 `home-pc`로 변경)
2. Android 앱 빌드 (Android Studio)
3. 자동배포 MCP 도구 추가 예정
