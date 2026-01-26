# 로그 시스템

> 디버깅을 위한 로그 파일 위치와 확인 방법

---

## Pylon 로그

### 위치

```
estelle-pylon/logs/
├── pylon-2026-01-25T10-30-00.log      # 일반 로그
├── packets-2026-01-25T10-30-00.jsonl  # 패킷 로그
└── ...
```

### 일반 로그 (pylon-*.log)

텍스트 형식. 서버 시작, 연결, 에러 등.

```
[2026-01-25T10:30:00.000Z] [INFO] Connected to Relay
[2026-01-25T10:30:05.000Z] [ERROR] Claude session error: ...
```

**확인 방법:**
```bash
# 최신 로그 실시간 확인
tail -f estelle-pylon/logs/pylon-*.log

# 에러만 필터
grep ERROR estelle-pylon/logs/pylon-*.log
```

### 패킷 로그 (packets-*.jsonl)

JSON Lines 형식. 모든 송수신 패킷 기록.

```json
{"timestamp":"2026-01-25T10:30:00.000Z","direction":"recv","source":"relay","type":"prompt","data":{...}}
{"timestamp":"2026-01-25T10:30:01.000Z","direction":"send","target":"relay","type":"claude_message","data":{...}}
```

**확인 방법:**
```bash
# 특정 메시지 타입 필터
grep '"type":"permission_request"' estelle-pylon/logs/packets-*.jsonl

# jq로 예쁘게 보기
tail -1 estelle-pylon/logs/packets-*.jsonl | jq .

# 최근 10개 패킷
tail -10 estelle-pylon/logs/packets-*.jsonl
```

### 로그 정책

- 최대 50개 파일 유지
- 실행할 때마다 새 파일 생성
- 오래된 파일 자동 삭제

---

## App 로그

> ⚠️ 현재 App은 파일 로그 없음. 콘솔 출력만.

### Flutter 디버그 콘솔

```bash
# 데스크톱 실행 시 콘솔에 출력됨
flutter run -d windows
```

### TODO: App 파일 로그 추가

필요 시 구현:
- `estelle-app/logs/` 폴더
- RelayService 송수신 로깅
- Provider 상태 변경 로깅

---

## Relay 로그

Fly.io 콘솔에서 확인:

```bash
fly logs -a estelle-relay
```

또는 Fly.io 대시보드에서 Monitoring → Logs

---

## 디버깅 팁

### 1. 메시지가 안 오는 경우

```bash
# Pylon에서 Relay 연결 확인
grep "Connected to Relay" estelle-pylon/logs/pylon-*.log

# 패킷 수신 확인
grep '"direction":"recv"' estelle-pylon/logs/packets-*.jsonl | tail -5
```

### 2. Claude 응답이 안 오는 경우

```bash
# Claude 에러 확인
grep -i "claude\|error" estelle-pylon/logs/pylon-*.log

# prompt 수신 확인
grep '"type":"prompt"' estelle-pylon/logs/packets-*.jsonl
```

### 3. 권한 요청 문제

```bash
# permission_request 송신 확인
grep '"type":"permission_request"' estelle-pylon/logs/packets-*.jsonl

# permission_response 수신 확인
grep '"type":"permission_response"' estelle-pylon/logs/packets-*.jsonl
```

---

## 로그 파일 위치 요약

| 컴포넌트 | 위치 | 형식 |
|----------|------|------|
| Pylon 일반 | `estelle-pylon/logs/pylon-*.log` | 텍스트 |
| Pylon 패킷 | `estelle-pylon/logs/packets-*.jsonl` | JSON Lines |
| Relay | Fly.io 콘솔 (`fly logs`) | 텍스트 |
| App | 없음 (콘솔만) | - |
