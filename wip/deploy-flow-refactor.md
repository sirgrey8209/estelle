# 배포 시스템 리팩토링

## 개요
배포 프로세스를 2단계로 분리: 준비(빌드) → 실행(재시작)

## 현재 구현 상태

### 구현됨 ✅
- `deploy_prepare` → `deploy_ready` → `deploy_go` → `deploy_restarting` 흐름
- 주도 Pylon 선택 UI
- git pull, fly deploy, APK 빌드
- 자가패치 (self-patch.bat)

### 미구현 ❌
- 진행상황 실시간 브로드캐스트
- 다른 Pylon 자가배포
- 핸드셰이크 (앱/다른 Pylon 준비 확인)

---

## 수정된 설계

### 2단계 배포 흐름 (단순화)

#### 1단계: 배포 준비 (deploy_prepare)

**주도 Pylon**
```
1. deploy_status 브로드캐스트 시작 (1초 간격)
2. git fetch && git pull
3. (relayDeploy=true일 때만)
   ├── fly deploy
   └── APK 빌드 & GitHub Release 업로드
4. npm install
5. deploy_ready 전송
```

**다른 Pylon** (relayDeploy=false)
```
1. git fetch && git pull
2. npm install
3. deploy_ready 전송
```

**앱**
```
- deploy_status 수신 → UI 표시
- 모든 Pylon deploy_ready 수신 → GO 버튼 활성화
```

#### 2단계: 배포 실행 (deploy_go)

**GO 버튼 클릭 후**
```
앱 → broadcast: deploy_go
```

**모든 Pylon** (동시)
```
1. deploy_restarting 전송
2. self-patch.bat 실행 (pm2 restart)
3. Relay 재연결
```

**앱**
```
1. 연결 끊김 감지
2. 재연결 대기 (자동)
3. (모바일) 새 APK 다운로드 안내
```

---

## 메시지 프로토콜

| 메시지 | 방향 | 페이로드 |
|--------|------|----------|
| `deploy_prepare` | App → Pylon | `{ relayDeploy: bool }` |
| `deploy_status` | Pylon → All (1초) | `{ deviceId, step, progress, message }` |
| `deploy_ready` | Pylon → All | `{ deviceId, success, error? }` |
| `deploy_go` | App → All | `{}` |
| `deploy_restarting` | Pylon → All | `{ deviceId }` |

### deploy_status.step 값
- `git_pull` - git fetch && pull 중
- `fly_deploy` - Relay 배포 중 (주도 Pylon만)
- `apk_build` - APK 빌드 중 (주도 Pylon만)
- `apk_upload` - APK 업로드 중 (주도 Pylon만)
- `npm_install` - npm install 중
- `done` - 완료

---

## 수정 파일

### estelle-pylon/src/index.js
- [ ] `broadcastDeployStatus(step, message)` 추가
- [ ] `handleDeployPrepare()` 리팩토링 - status 브로드캐스트 추가
- [ ] 다른 Pylon도 git pull + npm install 수행하도록 수정

### estelle-app/lib/data/services/relay_service.dart
- [x] `sendDeployPrepare()` - 구현됨
- [x] `sendDeployGo()` - 구현됨

### estelle-app/lib/ui/widgets/deploy/deploy_dialog.dart
- [ ] `deploy_status` 메시지 핸들링 추가
- [ ] 각 Pylon별 진행상황 표시
- [ ] 단계별 상세 메시지 표시

---

## 타임라인 예시

```
0:00  [앱] 배포 버튼 → deploy_prepare 전송
0:01  [P1] status: "git pull 중..."
0:01  [P2] status: "git pull 중..."
0:03  [P1] status: "fly deploy 중..." (주도)
0:03  [P2] status: "npm install 중..."
0:10  [P2] deploy_ready (success)
1:00  [P1] status: "APK 빌드 중..."
2:00  [P1] status: "APK 업로드 중..."
2:10  [P1] status: "npm install 중..."
2:20  [P1] deploy_ready (success)
2:20  [앱] 모든 Pylon ready → GO 버튼 활성화

      --- 유저가 GO 버튼 클릭 ---

2:25  [앱] deploy_go 브로드캐스트
2:26  [P1, P2] deploy_restarting → 재시작
2:30  [P1, P2] Relay 재연결
2:30  [앱] 재연결 완료
```

---

## 에지 케이스

### 배포 중 Pylon 오류
- 해당 Pylon만 `deploy_ready { success: false, error }` 전송
- 앱에서 오류 표시, 나머지 Pylon은 계속 진행 가능

### 일부 Pylon만 배포
- 현재는 broadcast로 모든 Pylon에 전송
- TODO: Pylon 선택 기능 (체크박스)

### Relay 배포 실패
- fly deploy 실패해도 Pylon 배포는 계속 진행
- 앱에서 경고 표시

---

*Last updated: 2026-01-23*
