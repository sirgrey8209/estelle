# 배포 메시지 흐름

## 접속 상태

| 디바이스 | deviceId | 역할 |
|----------|----------|------|
| Pylon 1 (P1) | 1 | 주도 Pylon (relayDeploy=true) |
| Pylon 2 (P2) | 2 | |
| Desktop 1 (D1) | 101 | 배포 트리거 |
| Desktop 2 (D2) | 102 | |
| Mobile (M) | 103 | |

---

## 메시지 흐름

### 시나리오 A: 빌드 완료 후 확인

```
[0:00]  D1 → P1: deploy_prepare
[0:01]  P1 → D1: deploy_status { Git(진행중) APK(대기) EXE(대기) NPM(대기) }
[0:03]  P1 → D1: deploy_status { Git(✓) APK(빌드중) EXE(대기) NPM(대기) }
[1:00]  P1 → D1: deploy_status { Git(✓) APK(빌드중) NPM(진행중) }
[1:20]  P1 → D1: deploy_status { Git(✓) APK(✓) EXE(✓) NPM(진행중) }
[1:30]  P1 → D1: deploy_status { Git(✓) APK(✓) EXE(✓) NPM(✓) JSON(대기) }
[1:40]  P1 → D1: deploy_status { Git(✓) APK(✓) EXE(✓) NPM(✓) JSON(✓) }
[1:45]  P1 → D1: deploy_ready

        --- D1 UI: [확인] 버튼 클릭 ---

[1:46]  D1 → P1: deploy_confirm
[1:47]  P1 → All: deploy_start
[1:55]  P2 → P1: deploy_start_ack

        --- D1 UI: GO 버튼 활성화 ---

[2:00]  D1 → All: deploy_go
[2:01]  P1 → All: deploy_status { APK(업로드중) EXE(대기) Relay(대기) }
[2:10]  P1 → All: deploy_status { APK(✓) EXE(✓) Relay(배포중) }
[3:00]  P1 → All: deploy_status { APK(✓) EXE(✓) Relay(✓) }
[3:01]  P1 → All: deploy_restart
        ... (재시작)
```

### 시나리오 B: 사전 승인 (빌드 중 미리 확인)

```
[0:00]  D1 → P1: deploy_prepare
[0:01]  P1 → D1: deploy_status { Git(진행중) APK(대기) EXE(대기) NPM(대기) }

        --- D1 UI: [확인] 버튼 미리 클릭 (사전 승인) ---

[0:02]  D1 → P1: deploy_confirm { preApproved: true }

[0:03]  P1 → D1: deploy_status { Git(✓) APK(빌드중) EXE(대기) NPM(대기) }
[1:20]  P1 → D1: deploy_status { Git(✓) APK(✓) EXE(✓) NPM(진행중) }
[1:40]  P1 → D1: deploy_status { Git(✓) APK(✓) EXE(✓) NPM(✓) JSON(✓) }
[1:45]  P1 → D1: deploy_ready

        --- P1: 이미 confirm 받았으므로 바로 deploy_start ---

[1:46]  P1 → All: deploy_start
[1:54]  P2 → P1: deploy_start_ack

        --- D1 UI: GO 버튼 활성화 ---
```

### 시나리오 C: 사전 승인 후 취소

```
[0:00]  D1 → P1: deploy_prepare
[0:01]  P1 → D1: deploy_status { Git(진행중) APK(대기) EXE(대기) NPM(대기) }

        --- D1 UI: [확인] 버튼 클릭 (사전 승인) ---

[0:02]  D1 → P1: deploy_confirm { preApproved: true }

        --- D1 UI: [확인] 버튼 다시 클릭 (취소) ---

[0:10]  D1 → P1: deploy_confirm { cancel: true }

        --- P1: 사전 승인 취소됨, ready 후 confirm 대기 ---

[1:45]  P1 → D1: deploy_ready

        --- D1 UI: [확인] 버튼 클릭 필요 ---
```

---

## 메시지 상세

### deploy_prepare
```json
{
  "type": "deploy_prepare",
  "to": { "deviceId": 1, "deviceType": "pylon" },
  "payload": { "relayDeploy": true }
}
```

### deploy_status
```json
{
  "type": "deploy_status",
  "to": 101,
  "payload": {
    "deviceId": 1,
    "tasks": {
      "git": "done",
      "apk": "building",
      "npm": "waiting"
    },
    "message": "Git(✓) APK(빌드중) EXE(대기) NPM(대기)"
  }
}
```

### deploy_ready
```json
{
  "type": "deploy_ready",
  "to": 101,
  "payload": {
    "deviceId": 1,
    "success": true,
    "commitHash": "abc1234",
    "version": "1.0.5"
  }
}
```

### deploy_confirm
```json
{
  "type": "deploy_confirm",
  "to": { "deviceId": 1, "deviceType": "pylon" },
  "payload": {
    "preApproved": true,
    "cancel": false
  }
}
```
- `preApproved: true` - 빌드 완료 전 미리 승인
- `cancel: true` - 승인 취소 (토글)

### deploy_start
```json
{
  "type": "deploy_start",
  "broadcast": "all",
  "payload": {
    "commitHash": "abc1234",
    "version": "1.0.5",
    "leadPylonId": 1
  }
}
```

### deploy_start_ack
```json
{
  "type": "deploy_start_ack",
  "to": { "deviceId": 1, "deviceType": "pylon" },
  "payload": {
    "deviceId": 2,
    "success": true
  }
}
```

### deploy_go
```json
{
  "type": "deploy_go",
  "broadcast": "all",
  "payload": {}
}
```

### deploy_restart
```json
{
  "type": "deploy_restart",
  "broadcast": "all",
  "payload": {}
}
```

### deploy_restarting
```json
{
  "type": "deploy_restarting",
  "broadcast": "all",
  "payload": { "deviceId": 2 }
}
```

---

## 상태 표시 형식

P1 내부 병렬 빌드 상태 표시 (P2는 Relay 배포 시 연결 끊김 가능성 있어 생략)

```
Git(✓) APK(빌드중) NPM(✓)
```

### 상태 값
- `✓` - 완료
- `✗` - 실패
- `대기` - 아직 시작 안 함
- `진행중` 또는 구체적 단계명

### 단계별 표시
| 단계 | 표시 |
|------|------|
| git pull | `Git(진행중)` → `Git(✓)` |
| APK 빌드 | `APK(빌드중)` → `APK(✓)` |
| EXE 빌드 | `EXE(빌드중)` → `EXE(✓)` |
| npm install | `NPM(진행중)` → `NPM(✓)` |
| deploy.json | `JSON(업데이트중)` → `JSON(✓)` |
| APK 업로드 | `APK(업로드중)` → `APK(✓)` |
| EXE 업로드 | `EXE(업로드중)` → `EXE(✓)` |
| fly deploy | `Relay(배포중)` → `Relay(✓)` |

### 예시
```
준비 단계: Git(✓) APK(빌드중) EXE(대기) NPM(대기)
빌드 완료: Git(✓) APK(✓) EXE(✓) NPM(✓) JSON(✓)
배포 단계: APK(업로드중) EXE(대기) Relay(대기)
```

---

## 메시지 타입 정리

| 메시지 | 방향 | 설명 |
|--------|------|------|
| `deploy_prepare` | D1 → P1 | 빌드 시작 요청 |
| `deploy_status` | P → D1 or All | 진행상황 (간략 형식) |
| `deploy_ready` | P1 → D1 | P1 빌드 완료 |
| `deploy_confirm` | D1 → P1 | 사용자 확인 (토글: 승인/취소) |
| `deploy_start` | P1 → All | 다른 Pylon 준비 시작 |
| `deploy_start_ack` | P2 → P1 | 준비 완료 |
| `deploy_go` | D1 → All | 배포 실행 |
| `deploy_restart` | P1 → All | Pylon 재시작 시그널 |
| `deploy_restarting` | P → All | 재시작 중 알림 |

---

## UI 상태 머신

```
[시작] → [빌드 중] → [빌드 완료] → [준비 중] → [준비 완료] → [배포 중] → [완료]
              ↓              ↓
         [사전 승인]    [승인 대기]
              ↓              ↓
         [승인 취소] ←─────────┘
```

### 버튼 상태
| 상태 | [확인] 버튼 | [GO] 버튼 |
|------|------------|----------|
| 빌드 중 | "미리 승인" (토글) | 비활성 |
| 빌드 완료 (미승인) | "승인" | 비활성 |
| 빌드 완료 (승인됨) | "승인 취소" (토글) | 비활성 |
| 준비 중 | 비활성 | 비활성 |
| 준비 완료 | 비활성 | **활성** |
| 배포 중 | 비활성 | 비활성 |

---

*Last updated: 2026-01-23*
