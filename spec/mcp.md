# MCP 서버

> Estelle Deploy MCP - 배포 자동화

---

## 개요

Claude Code에서 직접 배포를 실행할 수 있는 MCP 서버.

**위치**: `estelle-pylon/src/mcp.js`

---

## 설정

### Claude Code 설정

`~/.claude/claude_desktop_config.json` 또는 프로젝트 설정에 추가:

```json
{
  "mcpServers": {
    "estelle-deploy": {
      "command": "node",
      "args": ["src/mcp.js"],
      "cwd": "C:\\workspace\\estelle\\estelle-pylon"
    }
  }
}
```

### 참고 파일

`estelle-pylon/mcp-config.json`에 예시 설정 있음.

---

## 도구

### deploy_status

Git 상태 및 배포 가능 여부 확인.

**입력**: 없음

**출력**:
```json
{
  "branch": "main",
  "localCommit": "abc1234",
  "hasUncommittedChanges": false,
  "changedFiles": 0,
  "canDeploy": true,
  "repoDir": "C:\\workspace\\estelle"
}
```

**사용 예**:
- 배포 전 상태 확인
- 커밋 안 된 변경사항 체크

---

### deploy_run

배포 실행. git sync → APK/EXE 빌드 → GitHub Release 업로드 → Relay 배포.

**입력**:
```json
{
  "skipRelay": false  // Relay 배포 스킵 여부 (선택)
}
```

**출력**: 배포 로그

**주의**:
- 커밋 안 된 변경사항 있으면 실패
- 약 10분 소요 (타임아웃 600초)

---

## 사용법

Claude Code에서:

```
배포 상태 확인해줘
→ deploy_status 도구 호출

배포 실행해줘
→ deploy_run 도구 호출

Relay 빼고 배포해줘
→ deploy_run(skipRelay: true) 호출
```

---

## 내부 동작

1. `deploy_status`:
   - `git status --porcelain`
   - `git branch --show-current`
   - `git rev-parse --short HEAD`

2. `deploy_run`:
   - 먼저 git status 확인
   - 변경사항 있으면 중단
   - `scripts/p1-deploy.ps1` 실행

---

## 관련 파일

| 파일 | 설명 |
|------|------|
| `estelle-pylon/src/mcp.js` | MCP 서버 코드 |
| `estelle-pylon/mcp-config.json` | 설정 예시 |
| `scripts/p1-deploy.ps1` | 실제 배포 스크립트 |
