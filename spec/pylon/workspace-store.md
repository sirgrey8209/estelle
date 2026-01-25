# WorkspaceStore

> 워크스페이스와 대화 영속 저장소

## 위치

`estelle-pylon/src/workspaceStore.js`

---

## 역할

- 워크스페이스 CRUD (생성, 조회, 수정, 삭제)
- 대화 CRUD
- 활성 워크스페이스/대화 관리
- 설정 저장 (권한 모드 등)

---

## 저장 파일

| 파일 | 내용 |
|------|------|
| `workspaces.json` | 워크스페이스 및 대화 목록 |
| `pylon-settings.json` | Pylon 설정 |

---

## 데이터 구조

### workspaces.json

```json
{
  "activeWorkspaceId": "ws-uuid",
  "activeConversationId": "conv-uuid",
  "workspaces": [
    {
      "workspaceId": "ws-uuid",
      "name": "Estelle",
      "workingDir": "C:\\workspace\\estelle",
      "conversations": [
        {
          "conversationId": "conv-uuid",
          "name": "기능 논의",
          "skillType": "general",
          "claudeSessionId": "session-uuid",
          "status": "idle",
          "unread": false,
          "createdAt": 1706180400000
        }
      ],
      "createdAt": 1706180400000,
      "lastUsed": 1706180500000
    }
  ]
}
```

### Conversation 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `conversationId` | `string` | UUID |
| `name` | `string` | 대화 이름 |
| `skillType` | `string` | 스킬 타입 (general/planner/worker) |
| `claudeSessionId` | `string?` | Claude 세션 ID (resume용) |
| `status` | `string` | 상태 (idle/working/waiting/error) |
| `unread` | `boolean` | 읽지 않은 메시지 여부 |
| `createdAt` | `number` | 생성 시간 |

---

## 메서드

### Workspace 관련

#### getAllWorkspaces()

모든 워크스페이스 목록

```javascript
const workspaces = workspaceStore.getAllWorkspaces();
// → [{ ...workspace, isActive: true/false }, ...]
```

#### getWorkspace(workspaceId)

특정 워크스페이스 조회

#### createWorkspace(name, workingDir)

새 워크스페이스 생성

```javascript
const { workspace, conversation } = workspaceStore.createWorkspace('My Project', 'C:\\path');
```

- 첫 번째 대화 "새 대화" 자동 생성
- 생성된 워크스페이스를 활성화

#### deleteWorkspace(workspaceId)

워크스페이스 삭제

- 삭제된 워크스페이스가 활성이면 다른 워크스페이스로 전환

#### renameWorkspace(workspaceId, newName)

워크스페이스 이름 변경

#### setActiveWorkspace(workspaceId, conversationId?)

활성 워크스페이스 설정

---

### Conversation 관련

#### getConversation(workspaceId, conversationId)

특정 대화 조회

#### createConversation(workspaceId, name, skillType)

새 대화 생성

```javascript
const conv = workspaceStore.createConversation(wsId, '새 대화', 'planner');
```

| skillType | 설명 |
|-----------|------|
| `general` | 일반 대화 |
| `planner` | 계획 수립 |
| `worker` | 구현 |

#### deleteConversation(workspaceId, conversationId)

대화 삭제

- 삭제된 대화가 활성이면 다른 대화로 전환

#### renameConversation(workspaceId, conversationId, newName)

대화 이름 변경

#### updateConversationStatus(workspaceId, conversationId, status)

대화 상태 업데이트

| status | 설명 |
|--------|------|
| `idle` | 대기 |
| `working` | 작업 중 |
| `waiting` | 권한/질문 대기 |
| `error` | 에러 |

#### updateConversationUnread(workspaceId, conversationId, unread)

읽지 않음 상태 업데이트

#### updateClaudeSessionId(workspaceId, conversationId, sessionId)

Claude 세션 ID 업데이트 (resume용)

---

### Utility

#### findWorkspaceByName(name)

이름으로 워크스페이스 검색 (대소문자 무시, 부분 일치)

#### findWorkspaceByConversation(conversationId)

대화 ID로 워크스페이스 ID 찾기

#### getPermissionMode()

현재 권한 모드 조회

```javascript
const mode = workspaceStore.getPermissionMode();
// → 'default' | 'acceptEdits' | 'bypassPermissions'
```

#### setPermissionMode(mode)

권한 모드 설정

---

## 상태 조회

### getActiveState()

활성 워크스페이스/대화 ID

```javascript
const { activeWorkspaceId, activeConversationId } = workspaceStore.getActiveState();
```

### getActiveWorkspace()

활성 워크스페이스 객체

### getActiveConversation()

활성 대화 객체

---

## 관련 문서

- [overview.md](./overview.md) - Pylon 개요
- [message-store.md](./message-store.md) - 메시지 저장소
- [claude-manager.md](./claude-manager.md) - Claude 세션 관리
