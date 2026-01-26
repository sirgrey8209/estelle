# Flutter 웹 개발 서버 Pylon 통합

## 상태: WIP (Hold)

## 목표
Pylon에서 Flutter 웹 개발 서버를 관리하여 Claude가 코드 수정 후 자동으로 Hot Reload를 트리거할 수 있게 함

## 현재 진행 상황

### 완료
- [x] FlutterDevManager 클래스 생성 (`estelle-pylon/src/flutterDevManager.js`)
  - Pylon당 1개 서버 관리 (단일 상태)
  - 시작 시 기존 포트 점유 프로세스 kill
  - spawn으로 Flutter CLI 실행
  - stdin으로 r/R/q 명령 전송
  - stdout 파싱으로 서버 ready, reload 완료 감지

### 보류 중
- [ ] MCP 통합 방식 결정 필요
- [ ] Pylon index.js 업데이트
- [ ] Flutter 앱 웹 환경 reload 처리

## 아키텍처 이슈

### MCP 통합 문제
MCP 서버는 **별도 프로세스**로 실행되어 Pylon의 FlutterDevManager에 직접 접근 불가

**옵션:**
1. **MCP에서 직접 관리** - MCP 프로세스에서 FlutterDevManager 인스턴스 생성 (Pylon과 독립)
2. **Pylon 메시지로 위임** - MCP는 알림만 보내고, Pylon이 실제 실행 (복잡)
3. **Pylon 내부 MCP로 변경** - MCP 서버를 Pylon 내부에서 실행 (대규모 변경)

## 구현된 코드

### FlutterDevManager API

```javascript
class FlutterDevManager {
  constructor(onEvent)

  // 초기화 (기존 프로세스 정리)
  async initialize(appDir)

  // 서버 제어
  async start(options = { port: 8080 })
  stop()
  hotReload()    // stdin.write('r')
  hotRestart()   // stdin.write('R')

  // 상태 조회
  getStatus()

  // 정리
  cleanup()
}
```

### 이벤트 타입

```javascript
{ type: 'server_starting', url }
{ type: 'server_ready', url }
{ type: 'reload_triggered' }
{ type: 'reload_complete' }
{ type: 'restart_triggered' }
{ type: 'restart_complete' }
{ type: 'server_stopped' }
{ type: 'server_crashed', exitCode }
{ type: 'error', error }
```

## 예정된 작업

### MCP 도구 (결정 후)
- `flutter_dev_start` - 웹 서버 시작
- `flutter_dev_stop` - 웹 서버 중지
- `flutter_dev_reload` - Hot Reload/Restart
- `flutter_dev_status` - 상태 확인

### Flutter 앱 (웹 전용)
- `flutter_event { type: 'reload_complete' }` 수신 시 `window.location.reload()` 호출

## 관련 파일
- `estelle-pylon/src/flutterDevManager.js` - 구현됨
- `estelle-pylon/src/index.js` - 수정 필요 (flutter 핸들러 업데이트)
- `estelle-pylon/src/mcp/index.js` - 방식 결정 후 수정
- `estelle-app/lib/...` - 웹 reload 처리 추가

## 메모
- SDK 버전: `@anthropic-ai/claude-agent-sdk@0.2.14`
- Flutter 웹 서버 기본 포트: 8080
- Hot Reload 명령: `r` (stdin)
- Hot Restart 명령: `R` (stdin)
- 종료 명령: `q` (stdin)
