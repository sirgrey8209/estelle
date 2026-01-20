# Estelle Pylon 명령어 가이드

Pylon을 파일 기반으로 제어하는 방법입니다.

## 개요

```
클로드 코드 → commands.json 작성 → Pylon 감지 → 실행 → results.json
```

## 파일 위치

| 파일 | 경로 | 용도 |
|------|------|------|
| 명령 파일 | `estelle-pylon/commands.json` | 명령 입력 |
| 결과 파일 | `estelle-pylon/results.json` | 실행 결과 |
| PID 파일 | `estelle-pylon/pylon.pid` | 프로세스 ID |

## 명령어 형식

### 기본 구조

```json
{
  "timestamp": 1234567890,
  "command": "명령어",
  "옵션": "값"
}
```

> `timestamp`는 중복 실행 방지용 (선택 사항)

---

## 명령어 목록

### 1. status - 상태 확인

```json
{
  "command": "status"
}
```

**결과:**
```json
{
  "timestamp": 1234567890,
  "command": "status",
  "success": true,
  "data": {
    "pid": 12345,
    "deviceId": "home-pc",
    "relayConnected": true,
    "desktopClients": 1,
    "uptime": 3600
  }
}
```

---

### 2. echo - Relay 에코 테스트

```json
{
  "command": "echo",
  "payload": "Hello World"
}
```

**결과:**
```json
{
  "success": true,
  "data": {
    "sent": true,
    "payload": "Hello World"
  }
}
```

---

### 3. send - Relay로 메시지 전송

```json
{
  "command": "send",
  "type": "chat",
  "data": {
    "message": "안녕하세요"
  }
}
```

**결과:**
```json
{
  "success": true,
  "data": {
    "sent": true
  }
}
```

---

### 4. notify - Desktop 알림

```json
{
  "command": "notify",
  "title": "알림 제목",
  "message": "알림 내용"
}
```

**결과:**
```json
{
  "success": true,
  "data": {
    "notified": 1
  }
}
```

---

### 5. broadcast - Desktop에 데이터 전송

```json
{
  "command": "broadcast",
  "data": {
    "type": "custom",
    "payload": { "key": "value" }
  }
}
```

---

### 6. restart - Pylon 재시작

```json
{
  "command": "restart"
}
```

**결과:**
```json
{
  "success": true,
  "data": {
    "restarting": true
  }
}
```

> Task Scheduler가 자동으로 다시 시작

---

### 7. stop - Pylon 종료

```json
{
  "command": "stop"
}
```

---

## 사용 예시

### Claude Code에서 사용

```bash
# 상태 확인
echo '{"command":"status"}' > estelle-pylon/commands.json

# 1초 대기 후 결과 확인
sleep 1 && cat estelle-pylon/results.json

# Desktop에 알림 보내기
echo '{"command":"notify","title":"Claude","message":"작업 완료!"}' > estelle-pylon/commands.json

# Pylon 재시작
echo '{"command":"restart"}' > estelle-pylon/commands.json
```

### 결과 확인

```bash
# 결과 파일 읽기
cat estelle-pylon/results.json

# jq로 성공 여부만 확인
cat estelle-pylon/results.json | jq '.success'
```

---

## 에러 처리

### 실패 시 결과

```json
{
  "timestamp": 1234567890,
  "command": "echo",
  "success": false,
  "data": null,
  "error": "Not connected to Relay"
}
```

### 일반적인 에러

| 에러 | 원인 |
|------|------|
| `Not connected to Relay` | Relay 연결 끊김 |
| `No Desktop clients connected` | Desktop 앱 미실행 |
| `Unknown command: xxx` | 잘못된 명령어 |

---

## PID 파일 활용

```bash
# 현재 Pylon PID 확인
cat estelle-pylon/pylon.pid

# Pylon 강제 종료
kill $(cat estelle-pylon/pylon.pid)

# Windows에서
taskkill /PID $(cat estelle-pylon/pylon.pid) /F
```

---

## 주의사항

1. **명령 파일은 실행 후 삭제됨** - 한 번 처리되면 commands.json이 삭제됩니다
2. **결과 파일은 덮어쓰기** - 새 명령 실행 시 이전 결과가 사라집니다
3. **timestamp 권장** - 같은 명령 중복 실행 방지를 위해 timestamp 포함 권장
4. **1초 폴링** - Pylon이 1초마다 명령 파일을 확인합니다
