# Task Manager

> 태스크 파일 관리 모듈

## 위치

`estelle-pylon/src/taskManager.js`

---

## 역할

- 워크스페이스별 `task/` 폴더 관리
- 태스크 MD 파일 CRUD
- Frontmatter 기반 메타데이터 파싱/생성

---

## 태스크 파일 형식

### 파일명

```
YYYYMMDD-title-kebab.md
```

예: `20260125-버튼-색상-변경.md`

### Frontmatter

```yaml
---
id: 550e8400-e29b-41d4-a716-446655440000
title: 버튼 색상 변경
status: pending
createdAt: 2026-01-24T10:00:00Z
startedAt:
completedAt:
error:
---

## 목표
...
```

---

## 상수

| 상수 | 값 | 설명 |
|------|-----|------|
| `TASK_FOLDER` | `task` | 태스크 폴더명 |
| `MAX_CONTENT_LENGTH` | `10000` | 본문 truncate 기준 |

---

## 태스크 상태 (Status)

| 상태 | 설명 |
|------|------|
| `pending` | 대기 중 |
| `running` | 실행 중 |
| `done` | 완료 |
| `failed` | 실패 |

---

## API

### listTasks(workingDir)

태스크 목록 조회 (메타데이터만)

```javascript
const result = taskManager.listTasks('/path/to/workspace');
// {
//   success: true,
//   tasks: [
//     { id, title, status, createdAt, startedAt, completedAt, error, fileName }
//   ]
// }
```

- 최신순 정렬 (파일명 내림차순)

### getTask(workingDir, taskId)

태스크 상세 조회 (본문 포함)

```javascript
const result = taskManager.getTask('/path/to/workspace', 'uuid');
// {
//   success: true,
//   task: { ...meta, content, truncated }
// }
```

- 10000자 초과 시 truncate + `truncated: true`

### createTask(workingDir, title, body)

태스크 생성

```javascript
const result = taskManager.createTask('/path/to/workspace', '버튼 색상 변경', '## 목표\n...');
// {
//   success: true,
//   task: { id, title, status: 'pending', createdAt, fileName, filePath }
// }
```

- UUID 자동 생성
- status: `pending`으로 초기화

### updateTaskStatus(workingDir, taskId, status, error?)

태스크 상태 업데이트

```javascript
taskManager.updateTaskStatus('/path/to/workspace', 'uuid', 'running');
taskManager.updateTaskStatus('/path/to/workspace', 'uuid', 'failed', '에러 메시지');
```

- `running` → `startedAt` 자동 설정
- `done` / `failed` → `completedAt` 자동 설정

### getNextPendingTask(workingDir)

다음 pending 태스크 조회 (FIFO)

```javascript
const task = taskManager.getNextPendingTask('/path/to/workspace');
// 가장 오래된 pending 태스크 반환, 없으면 null
```

### getRunningTask(workingDir)

실행 중인 태스크 조회

```javascript
const task = taskManager.getRunningTask('/path/to/workspace');
// running 상태 태스크 반환, 없으면 null
```

### getTaskFilePath(workingDir, taskId)

태스크 파일 경로 조회

```javascript
const filePath = taskManager.getTaskFilePath('/path/to/workspace', 'uuid');
// '/path/to/workspace/task/20260125-버튼-색상-변경.md'
```

---

## 내부 함수

### parseFrontmatter(content)

Frontmatter 파싱

```javascript
const { meta, body } = parseFrontmatter(fileContent);
// meta: { id, title, status, ... }
// body: "## 목표\n..."
```

### buildFrontmatter(meta)

Frontmatter 생성

```javascript
const frontmatter = buildFrontmatter({ id: '...', title: '...', ... });
// "---\nid: ...\ntitle: ...\n---"
```

### generateFileName(title)

파일명 생성

```javascript
const fileName = generateFileName('버튼 색상 변경');
// "20260125-버튼-색상-변경.md"
```

---

## 관련 문서

- [worker-manager.md](worker-manager.md) - 워커 관리
- [claude-manager.md](claude-manager.md) - Claude 세션 관리
