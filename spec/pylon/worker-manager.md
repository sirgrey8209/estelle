# Worker Manager

> 워커 프로세스 관리 모듈

## 위치

`estelle-pylon/src/workerManager.js`

---

## 역할

- 워크스페이스당 워커 1개 관리
- pending 태스크 자동 시작 (FIFO)
- Claude 프로세스 생명주기 관리

---

## 워커 상태 (WorkerState)

```javascript
{
  status: 'idle',           // 'idle' | 'running'
  currentTaskId: null,      // 현재 태스크 ID
  currentTaskTitle: null,   // 현재 태스크 제목
  startedAt: null,          // 시작 시간
  claudeProcess: null,      // Claude 프로세스 참조
  conversationId: null      // 워커용 대화 ID
}
```

---

## 저장소

```javascript
const workerStates = new Map(); // workspaceId → WorkerState
```

- 메모리 기반 (재시작 시 초기화)

---

## API

### getWorkerState(workspaceId)

워커 상태 조회

```javascript
const state = workerManager.getWorkerState('workspace-uuid');
// 없으면 새로 생성
```

### getWorkerStatus(workspaceId, workingDir)

API 응답용 상태 요약

```javascript
const status = workerManager.getWorkerStatus('workspace-uuid', '/path/to/workspace');
// {
//   workspaceId,
//   status: 'idle' | 'running',
//   currentTask: { id, title, startedAt } | null,
//   queue: { pending: 3, total: 10 }
// }
```

### canStartWorker(workspaceId, workingDir)

워커 시작 가능 여부 확인

```javascript
const check = workerManager.canStartWorker('workspace-uuid', '/path/to/workspace');
// { canStart: true, nextTask: { ... } }
// { canStart: false, reason: '워커가 이미 실행 중입니다.' }
// { canStart: false, reason: 'pending 태스크가 없습니다.' }
```

### startWorker(workspaceId, workingDir, startClaudeCallback)

워커 시작

```javascript
const result = await workerManager.startWorker(
  'workspace-uuid',
  '/path/to/workspace',
  async (workspaceId, workingDir, prompt) => {
    // Claude 프로세스 시작 로직
    return { process, conversationId };
  }
);
// { success: true, taskId, taskTitle }
// { success: false, error: '...' }
```

**프롬프트 형식**:
```
/es-task-worker {taskFilePath}를 꼼꼼히 구현 부탁해.
```

### completeWorker(workspaceId, workingDir, status, error?)

워커 완료 처리

```javascript
workerManager.completeWorker('workspace-uuid', '/path/to/workspace', 'done');
workerManager.completeWorker('workspace-uuid', '/path/to/workspace', 'failed', '에러 메시지');
```

- 태스크 상태 업데이트
- 워커 상태 초기화

### checkAndStartNext(workspaceId, workingDir, startClaudeCallback)

다음 태스크 자동 시작 체크

```javascript
const started = await workerManager.checkAndStartNext(
  'workspace-uuid',
  '/path/to/workspace',
  startClaudeCallback
);
// true: 시작됨, false: 시작 안 됨
```

### stopWorker(workspaceId, workingDir)

워커 강제 중지

```javascript
const result = workerManager.stopWorker('workspace-uuid', '/path/to/workspace');
// { success: true }
// { success: false, error: '실행 중인 워커가 없습니다.' }
```

- 태스크를 `pending`으로 되돌림 (재시도 가능)
- Claude 프로세스 종료는 호출자가 처리

### getAllWorkerStatuses()

모든 워커 상태 조회 (브로드캐스트용)

```javascript
const statuses = workerManager.getAllWorkerStatuses();
// [{ workspaceId, status, currentTaskId, currentTaskTitle, startedAt }, ...]
```

---

## 워커 실행 흐름

```
1. canStartWorker() 체크
   ├─ 이미 running → 불가
   └─ pending 없음 → 불가

2. startWorker() 호출
   ├─ 태스크 상태 → running
   ├─ 워커 상태 업데이트
   └─ Claude 프로세스 시작

3. Claude 작업 완료
   └─ completeWorker() 호출
       ├─ 태스크 상태 → done/failed
       └─ 워커 상태 초기화

4. checkAndStartNext()
   └─ 다음 pending 태스크 자동 시작
```

---

## 관련 문서

- [task-manager.md](task-manager.md) - 태스크 파일 관리
- [claude-manager.md](claude-manager.md) - Claude 세션 관리
