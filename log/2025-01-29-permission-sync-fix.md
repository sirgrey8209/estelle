# 퍼미션 동기화 버그 수정

**날짜**: 2025-01-29
**작업자**: Claude
**관련 파일**:
- `estelle-pylon/src/workspaceStore.js`
- `estelle-pylon/src/claudeManager.js`
- `estelle-pylon/src/index.js`

## 문제

Pylon이 재시작되면 퍼미션 모드가 `default`로 동작하는 버그.

### 원인

퍼미션 모드 조회 함수가 `workspaceId`를 필수로 요구했는데, Pylon 재시작 후에는 `workspaceId`가 설정되지 않아서 항상 `'default'`를 반환함.

```javascript
// 기존 코드 (claudeManager.js)
async handlePermission(sessionId, toolName, input) {
  const mode = ClaudeManager.getPermissionMode(this.currentWorkspaceId, sessionId);
  // this.currentWorkspaceId가 undefined면 → 'default' 반환
}
```

`this.currentWorkspaceId`는 `sendMessage()` 호출 시에만 설정되므로:
1. Pylon 재시작
2. Claude 세션이 resume되거나 권한 요청 발생
3. `handlePermission()` 호출
4. `this.currentWorkspaceId`가 `undefined`
5. 퍼미션 모드를 찾지 못하고 `'default'` 반환

## 해결

`conversationId`는 UUID로 전역 유니크하므로, `workspaceId` 없이 `conversationId`만으로 조회하도록 변경.

### 변경 내용

#### workspaceStore.js

```javascript
// Before
getConversationPermissionMode(workspaceId, conversationId) {
  const conv = this.getConversation(workspaceId, conversationId);
  return conv?.permissionMode || 'default';
}

setConversationPermissionMode(workspaceId, conversationId, mode) {
  // workspaceId로 workspace 찾고 → conversation 찾기
}

// After
getConversationPermissionMode(conversationId) {
  const store = this.load();
  for (const workspace of store.workspaces) {
    const conv = workspace.conversations.find(c => c.conversationId === conversationId);
    if (conv) return conv.permissionMode || 'default';
  }
  return 'default';
}

setConversationPermissionMode(conversationId, mode) {
  const store = this.load();
  for (const workspace of store.workspaces) {
    const conv = workspace.conversations.find(c => c.conversationId === conversationId);
    if (conv) {
      conv.permissionMode = mode;
      this.save(store);
      return true;
    }
  }
  return false;
}
```

#### claudeManager.js

```javascript
// Before
static setPermissionMode(workspaceId, conversationId, mode)
static getPermissionMode(workspaceId, conversationId)
this.currentWorkspaceId = workspaceId;  // sendMessage에서 설정

// After
static setPermissionMode(conversationId, mode)
static getPermissionMode(conversationId)
// this.currentWorkspaceId 제거
```

#### index.js

```javascript
// Before
if (type === 'claude_set_permission_mode') {
  const { workspaceId, conversationId, mode } = payload || {};
  if (workspaceId && conversationId && mode) {
    ClaudeManager.setPermissionMode(workspaceId, conversationId, mode);
  }
}

// After
if (type === 'claude_set_permission_mode') {
  const { conversationId, mode } = payload || {};
  if (conversationId && mode) {
    ClaudeManager.setPermissionMode(conversationId, mode);
  }
}
```

## 퍼미션 동기화 흐름 (참고)

### 저장 흐름
1. 앱에서 퍼미션 아이콘 클릭
2. `claude_set_permission_mode` 메시지 전송
3. Pylon이 `workspaces.json`에 저장

### 동기화 흐름
1. 앱 시작 → Relay 연결
2. `workspace_list_result` 수신
3. 각 대화의 `permissionMode`를 `permissionModeProvider`에 반영

### 퍼미션 적용 흐름
1. Claude가 도구 실행 시 `canUseTool` 콜백 호출
2. `handlePermission(sessionId, toolName, input)` 실행
3. `getPermissionMode(sessionId)`로 모드 조회
4. 모드에 따라 자동 허용/거부 또는 사용자에게 요청
