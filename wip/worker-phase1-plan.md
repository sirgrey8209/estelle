# Worker System Phase 1 - 구현 플랜

## 진행 상황 (2026-01-24)

**✅ 완료된 항목:**
- Step 1: Pylon 기반 작업 (workspaceStore, folderManager, taskManager, workerManager)
- Step 2: App UI 변경 (providers, sidebar, dialogs, task view, layouts)
- Step 3: Estelle MCP (task_create, task_list, worker_status)
- Step 4: 스킬 작성 (es-task-builder, es-task-worker)

**⏳ Phase 2로 연기:**
- 워커 자동 시작 (pending 태스크 감지 → 자동 시작)
- 워커 완료 감지 → 다음 태스크 시작
- 실시간 워커 채팅 표시
- workspaceId + conversationId 기반 메시지 관리
- 태스크 상태 변경 실시간 감지

---

## 개요

worker-phase1.md 기반 상세 구현 계획

---

## 구현 순서

```
1. Pylon 기반 작업 (API가 있어야 App이 동작)
2. App UI 변경
3. Estelle MCP
4. 스킬 작성
5. 통합 테스트
```

---

## Step 1: Pylon 기반 작업

### 1.1 데이터 구조 변경

**현재 deskStore 구조:**
```javascript
{
  deskId: "uuid",
  name: "작업명",
  workingDir: "C:\\path",
  isActive: true,
  claudeSessionId: "session-uuid",
  status: "idle"
}
```

**새로운 workspaceStore 구조:**
```javascript
{
  workspaceId: "uuid",
  name: "Estelle",
  workingDir: "C:\\workspace\\estelle",
  pylonId: 1,  // 어느 Pylon인지
  conversations: [
    {
      conversationId: "uuid",
      name: "기능 논의",
      claudeSessionId: "session-uuid",
      status: "idle",  // idle/working/waiting/error
      unread: false
    }
  ],
  // tasks는 파일 시스템에서 읽어옴
}
```

**작업:**
- [x] `workspaceStore.js` 생성 (deskStore 대체)
- [x] 마이그레이션 로직 (기존 데이터 무시, 새로 시작)
- [x] 워크스페이스 CRUD

### 1.2 폴더 API

**메시지 핸들러 추가:**

```javascript
// folder_list
{ type: 'folder_list', payload: { path: 'C:\\workspace' } }
→ { type: 'folder_list_result', payload: { path, folders: ['estelle', 'sandbox', ...] } }

// folder_create
{ type: 'folder_create', payload: { path: 'C:\\workspace', name: 'new-project' } }
→ { type: 'folder_create_result', payload: { success: true, path: 'C:\\workspace\\new-project' } }

// folder_rename
{ type: 'folder_rename', payload: { path: 'C:\\workspace\\old', newName: 'new' } }
→ { type: 'folder_rename_result', payload: { success: true, path: 'C:\\workspace\\new' } }
```

**작업:**
- [x] `folderManager.js` 생성
- [x] folder_list 핸들러
- [x] folder_create 핸들러
- [x] folder_rename 핸들러
- [x] 에러 처리 (권한, 존재하지 않는 경로 등)

### 1.3 워크스페이스 API

**메시지 핸들러 수정:**

```javascript
// workspace_list (기존 desk_list 대체)
{ type: 'workspace_list' }
→ { type: 'workspace_list_result', payload: { workspaces: [...] } }

// workspace_create (기존 desk_create 대체)
{ type: 'workspace_create', payload: { name, workingDir } }
→ { type: 'workspace_create_result', payload: { workspace } }

// workspace_delete
{ type: 'workspace_delete', payload: { workspaceId } }

// conversation_create (워크스페이스 내 대화 생성)
{ type: 'conversation_create', payload: { workspaceId, name } }
→ { type: 'conversation_create_result', payload: { conversation } }
```

**작업:**
- [x] desk_* 메시지 → workspace_* 로 변경
- [x] conversation_create 핸들러 추가
- [x] 응답 구조 변경

### 1.4 태스크 관리

**task/ 폴더 읽기:**

```javascript
// task_list
{ type: 'task_list', payload: { workspaceId } }
→ { type: 'task_list_result', payload: { tasks: [
  { id, title, status, createdAt }  // 메타만
] } }

// task_get
{ type: 'task_get', payload: { workspaceId, taskId } }
→ { type: 'task_get_result', payload: { content: "전체 MD" } }
```

**작업:**
- [x] `taskManager.js` 생성
- [x] task/ 폴더 스캔 (frontmatter 파싱)
- [x] task_list 핸들러
- [x] task_get 핸들러 (길면 truncate)
- [ ] task 상태 변경 감지 (파일 워치? 폴링?) - Phase 2

### 1.5 워커 프로세스 관리

**워커 로직:**

```javascript
// 워크스페이스별 워커 상태
workerState = {
  workspaceId: {
    status: 'idle' | 'running',
    currentTaskId: null,
    claudeProcess: null
  }
}

// 워커 시작 조건
// - pending 태스크 있음
// - 현재 running 태스크 없음

// 워커 시작
function startWorker(workspaceId, taskId) {
  const taskPath = getTaskPath(workspaceId, taskId);
  const prompt = `/es-task-worker ${taskPath}를 꼼꼼히 구현 부탁해.`;
  // Claude 프로세스 시작
}
```

**작업:**
- [x] `workerManager.js` 생성
- [x] 워커 상태 관리
- [ ] pending 태스크 감지 → 자동 시작 - Phase 2
- [ ] 태스크 완료 감지 → 다음 태스크 시작 - Phase 2
- [x] worker_status 응답

---

## Step 2: App UI 변경

### 2.1 상태 모델 변경

**현재 (Riverpod):**
- `deskListProvider` - Pylon별 데스크 목록
- `selectedDeskProvider` - 선택된 데스크
- `messagesProvider` - 메시지 목록

**새로운:**
- `workspaceListProvider` - 워크스페이스 목록
- `selectedWorkspaceProvider` - 선택된 워크스페이스
- `selectedItemProvider` - 선택된 대화/태스크
- `conversationMessagesProvider` - 대화 메시지
- `taskContentProvider` - 태스크 MD 내용

**작업:**
- [x] workspace 관련 Provider 생성
- [x] 기존 desk Provider 유지 (하위 호환)
- [x] 상태 닷 우선순위 로직

### 2.2 사이드바 UI

**현재:**
- PylonGroup > DeskItem 구조

**새로운:**
- WorkspaceItem (펼침/접힘) > ConversationItem / TaskItem

**작업:**
- [x] `WorkspaceItem` 위젯 (펼침/접힘, Pylon 아이콘)
- [x] `ConversationItem` 위젯 (💬 아이콘)
- [x] `TaskItem` 위젯 (📋 아이콘)
- [x] 상태 닷 표시 (🔴🟡🟢)
- [x] 접힌 상태 우선순위 닷
- [x] [+] 버튼 (대화 생성)

### 2.3 새 워크스페이스 다이얼로그

**구성:**
- Pylon 선택 (아이콘 + 이름)
- 경로 표시 + 상위 버튼
- 폴더 목록 (스크롤)
- 새 폴더 버튼
- 이름 입력 필드
- 취소/생성 버튼

**작업:**
- [x] `NewWorkspaceDialog` 위젯
- [x] Pylon 사이클 로직
- [x] 폴더 목록 로드 (folder_list 호출)
- [x] 폴더 선택 → 이름 자동입력
- [x] 폴더 더블탭 → 하위 이동
- [x] 폴더 롱프레스 → 이름 변경 다이얼로그
- [x] 새 폴더 생성
- [x] 기본 경로: C:/workspace

### 2.4 메인 영역 - 대화

**기존과 유사:**
- 채팅 UI
- 메시지 입력

**작업:**
- [x] 기존 채팅 UI 재사용
- [ ] workspaceId + conversationId 기반으로 변경 - Phase 2

### 2.5 메인 영역 - 태스크

**구성:**
- [MD] / [채팅] 탭
- MD 탭: 태스크 파일 내용 (마크다운 렌더링?)
- 채팅 탭: 워커 상태에 따라 다름

**작업:**
- [x] `TaskDetailView` 위젯
- [x] 탭 전환 (MD / 채팅)
- [x] MD 탭 - 내용 표시
- [x] 채팅 탭 - 상태별 표시
  - [x] pending: "작업 중이 아닙니다"
  - [ ] running: 실시간 채팅 - Phase 2
  - [x] done/failed: 히스토리 + "작업이 종료되었습니다"

---

## Step 3: Estelle MCP

### 3.1 MCP 서버 구조

**위치:** `estelle-pylon/src/mcp/`

```
mcp/
  index.js        # MCP 서버 메인
  tools/
    task_create.js
    task_list.js
    worker_status.js
```

**작업:**
- [x] MCP 서버 기본 구조 (stdio)
- [x] 도구 등록 로직

### 3.2 task_create

```javascript
{
  name: "task_create",
  description: "새 태스크 생성",
  parameters: {
    title: { type: "string", description: "제목 (8~10자)" },
    content: { type: "string", description: "MD 본문" }
  }
}
```

**동작:**
1. GUID 생성
2. 파일명 생성 (날짜 + title kebab)
3. frontmatter 추가
4. task/ 폴더에 저장
5. 결과 반환

**작업:**
- [x] task_create 도구 구현
- [x] frontmatter 생성 로직
- [x] 파일 저장

### 3.3 task_list

```javascript
{
  name: "task_list",
  description: "태스크 목록 조회",
  parameters: {
    status: { type: "string", optional: true }
  }
}
```

**작업:**
- [x] task_list 도구 구현
- [x] taskManager 연동

### 3.4 worker_status

```javascript
{
  name: "worker_status",
  description: "워커 상태 조회",
  parameters: {}
}
```

**작업:**
- [x] worker_status 도구 구현
- [x] workerManager 연동

---

## Step 4: 스킬 작성

### 4.1 es-task-builder

**위치:** 스킬 저장 경로 (TBD)

**내용:**
```markdown
# es-task-builder

대화용 스킬. 코딩하지 않고 계획/논의만 진행.

## 제한
- Edit, Write, Bash 사용 금지
- Read만 허용

## MCP 도구
- task_create: 태스크 생성
- task_list: 태스크 목록
- worker_status: 워커 상태

## 태스크 생성 시
- 제목은 한글 8~10자 이내
- 플랜은 명확하게 단계별로
```

**작업:**
- [x] 스킬 파일 작성
- [x] 도구 제한 설정

### 4.2 es-task-worker

**내용:**
```markdown
# es-task-worker

워커용 스킬. 태스크 파일을 읽고 구현.

## 허용
- Read, Edit, Write, Bash 모두 사용

## 동작
1. 인자로 받은 태스크 파일 읽기
2. 플랜 파악
3. 순서대로 구현
4. 완료 시 frontmatter 업데이트
   - status: done
   - completedAt: 현재 시간
5. 실패 시 frontmatter 업데이트
   - status: failed
   - error: 에러 내용
```

**작업:**
- [x] 스킬 파일 작성
- [x] frontmatter 업데이트 지침

---

## Step 5: 통합 테스트

### 5.1 시나리오 테스트

**시나리오 1: 워크스페이스 생성**
1. [+ 워크스페이스] 클릭
2. Pylon 선택 (아이콘 사이클)
3. 폴더 탐색 → 선택
4. 이름 확인 → 생성
5. 사이드바에 표시 확인

**시나리오 2: 대화 생성 및 태스크 등록**
1. 워크스페이스 펼침
2. [+] 클릭 → 대화 생성
3. 대화에서 "버튼 색상 빨간색으로" 요청
4. Claude가 플랜 작성 → task_create
5. task/ 폴더에 파일 생성 확인
6. 사이드바에 📋 태스크 표시

**시나리오 3: 워커 자동 실행**
1. pending 태스크 존재
2. 워커 자동 시작
3. 태스크 status → running
4. 채팅 탭에서 진행상황 확인
5. 완료 → status: done
6. 다음 pending 태스크 자동 시작

**작업:**
- [ ] 시나리오 1 테스트
- [ ] 시나리오 2 테스트
- [ ] 시나리오 3 테스트
- [ ] 에러 케이스 테스트

---

## 예상 작업량

| 단계 | 항목 | 예상 |
|------|------|------|
| Step 1 | Pylon 기반 | 중 |
| Step 2 | App UI | 대 |
| Step 3 | MCP | 소 |
| Step 4 | 스킬 | 소 |
| Step 5 | 테스트 | 중 |

---

## 의존성

```
Step 1.1 (데이터 구조)
    ↓
Step 1.2 (폴더 API) → Step 2.3 (워크스페이스 다이얼로그)
    ↓
Step 1.3 (워크스페이스 API) → Step 2.1, 2.2 (상태, 사이드바)
    ↓
Step 1.4 (태스크 관리) → Step 2.5 (태스크 메인 영역)
    ↓
Step 1.5 (워커 관리) → Step 3, 4 (MCP, 스킬)
    ↓
Step 5 (통합 테스트)
```

---

*Created: 2026-01-24*
