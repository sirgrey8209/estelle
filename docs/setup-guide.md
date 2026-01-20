# Estelle PC 세팅 가이드

## 사전 요구사항

- **Node.js 20+** - https://nodejs.org/
- **Git** - https://git-scm.com/

## 1. 리포지토리 클론

```bash
git clone https://github.com/sirgrey8209/estelle C:\workspace\estelle
cd C:\workspace\estelle
```

## 2. 자동 세팅 (권장)

관리자 권한 PowerShell에서 실행:

```powershell
.\scripts\setup-pc.ps1
```

스크립트가 자동으로:
- Node.js 버전 확인
- npm install 실행
- .env 파일 생성 (DEVICE_ID 입력 받음)
- Task Scheduler 등록

## 3. 수동 세팅

### 3-1. Pylon 설정

```bash
cd estelle-pylon
npm install
```

.env 파일 생성:
```bash
copy .env.example .env
```

.env 파일 수정:
```
RELAY_URL=wss://estelle-relay.fly.dev
LOCAL_PORT=9000
DEVICE_ID=my-device-name  # 예: office-pc, home-pc
```

### 3-2. Task Scheduler 등록 (관리자 권한)

```powershell
powershell -ExecutionPolicy Bypass -File estelle-pylon\scripts\install-service.ps1
```

### 3-3. Desktop 설정 (선택)

```bash
cd estelle-desktop
npm install
```

## 4. 확인

### Pylon Task 상태 확인

```powershell
Get-ScheduledTask -TaskName "EstellePylon*"
```

### 수동 시작

```powershell
Start-ScheduledTask -TaskName "EstellePylon"
```

### 수동 중지

```powershell
Stop-ScheduledTask -TaskName "EstellePylon"
```

### 로그 확인

```powershell
Get-Content C:\workspace\estelle\estelle-pylon\logs\updater.log -Tail 20
```

## 5. 제거

```powershell
powershell -ExecutionPolicy Bypass -File estelle-pylon\scripts\uninstall-service.ps1
```

## DEVICE_ID 권장 값

| PC | DEVICE_ID |
|----|-----------|
| 회사 PC | office-pc |
| 집 PC | home-pc |
| 노트북 | laptop |

## 트러블슈팅

### Pylon이 시작되지 않음

1. Node.js가 설치되어 있는지 확인
   ```powershell
   node --version
   ```

2. Task Scheduler에서 오류 확인
   ```powershell
   Get-ScheduledTaskInfo -TaskName "EstellePylon"
   ```

3. 수동으로 Pylon 실행해서 오류 확인
   ```bash
   cd estelle-pylon
   npm start
   ```

### 업데이트가 적용되지 않음

1. Updater 로그 확인
   ```powershell
   Get-Content estelle-pylon\logs\updater.log -Tail 50
   ```

2. Git 상태 확인
   ```bash
   git status
   git fetch origin main
   git log HEAD..origin/main --oneline
   ```
