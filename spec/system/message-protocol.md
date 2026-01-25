# 메시지 프로토콜

> Estelle 시스템의 모든 메시지 타입과 페이로드 형식

## 기본 구조

```json
{
  "type": "메시지_타입",
  "to": { "deviceId": 1, "deviceType": "pylon" },
  "broadcast": "clients",
  "from": { "deviceId": 100, "deviceType": "app", "name": "Client 100" },
  "payload": { ... }
}
```

| 필드 | 필수 | 설명 |
|------|------|------|
| `type` | Y | 메시지 타입 |
| `to` | N | 특정 디바이스로 전송 |
| `broadcast` | N | 브로드캐스트 대상 (`all`, `pylons`, `clients`, `app`) |
| `from` | N | 발신자 정보 (Relay가 자동 주입) |
| `payload` | N | 메시지 데이터 |

---

## 인증 메시지

### auth

**방향**: Client/Pylon → Relay

```json
{
  "type": "auth",
  "payload": {
    "deviceId": 1,           // Pylon만 필수 (1, 2 등)
    "deviceType": "pylon"    // "pylon" | "app"
  }
}
```

### auth_result

**방향**: Relay → Client/Pylon

```json
{
  "type": "auth_result",
  "payload": {
    "success": true,
    "device": {
      "deviceId": 100,
      "deviceType": "app",
      "name": "Client 100",
      "icon": "📱",
      "role": "client"
    },
    "error": "Auth failed reason"  // 실패 시
  }
}
```

---

## 디바이스 상태

### device_status

**방향**: Relay → 모든 클라이언트 (브로드캐스트)

```json
{
  "type": "device_status",
  "payload": {
    "devices": [
      {
        "deviceId": 1,
        "deviceType": "pylon",
        "name": "Selene",
        "icon": "🌙",
        "role": "home",
        "connectedAt": "2026-01-25T12:00:00.000Z"
      }
    ]
  }
}
```

### client_disconnect

**방향**: Relay → Pylon

```json
{
  "type": "client_disconnect",
  "payload": {
    "deviceId": 100,
    "deviceType": "app"
  }
}
```

---

## 워크스페이스 메시지

### workspace_list

**방향**: App → Pylon

```json
{
  "type": "workspace_list",
  "broadcast": "pylons"
}
```

### workspace_list_result

**방향**: Pylon → App

```json
{
  "type": "workspace_list_result",
  "payload": {
    "deviceId": 1,
    "deviceInfo": { "name": "Selene", "icon": "🌙" },
    "workspaces": [
      {
        "workspaceId": "ws-xxx",
        "name": "프로젝트명",
        "workingDir": "C:\\path\\to\\project",
        "conversations": [
          {
            "conversationId": "conv-xxx",
            "name": "대화 1",
            "skillType": "general",
            "status": "idle",
            "claudeSessionId": "session-xxx"
          }
        ],
        "tasks": [...],
        "workerStatus": { "running": false }
      }
    ],
    "activeWorkspaceId": "ws-xxx",
    "activeConversationId": "conv-xxx"
  }
}
```

### workspace_create

**방향**: App → Pylon

```json
{
  "type": "workspace_create",
  "to": { "deviceId": 1 },
  "payload": {
    "name": "새 워크스페이스",
    "workingDir": "C:\\path\\to\\project"
  }
}
```

### workspace_create_result

**방향**: Pylon → App

```json
{
  "type": "workspace_create_result",
  "payload": {
    "deviceId": 1,
    "success": true,
    "workspace": { ... },
    "conversation": { ... }
  }
}
```

### workspace_delete

**방향**: App → Pylon

```json
{
  "type": "workspace_delete",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx"
  }
}
```

### workspace_rename

**방향**: App → Pylon

```json
{
  "type": "workspace_rename",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "newName": "새 이름"
  }
}
```

### workspace_switch

**방향**: App → Pylon

```json
{
  "type": "workspace_switch",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx"
  }
}
```

---

## 대화 메시지

### conversation_create

**방향**: App → Pylon

```json
{
  "type": "conversation_create",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "name": "새 대화",
    "skillType": "general"  // "general" | "planner" | "worker"
  }
}
```

### conversation_create_result

**방향**: Pylon → App

```json
{
  "type": "conversation_create_result",
  "payload": {
    "deviceId": 1,
    "success": true,
    "workspaceId": "ws-xxx",
    "conversation": {
      "conversationId": "conv-xxx",
      "name": "새 대화",
      "skillType": "general"
    }
  }
}
```

### conversation_select

**방향**: App → Pylon

```json
{
  "type": "conversation_select",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx"
  }
}
```

### conversation_delete

**방향**: App → Pylon

```json
{
  "type": "conversation_delete",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx"
  }
}
```

### conversation_rename

**방향**: App → Pylon

```json
{
  "type": "conversation_rename",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx",
    "newName": "새 이름"
  }
}
```

### conversation_status

**방향**: Pylon → App (브로드캐스트)

```json
{
  "type": "conversation_status",
  "broadcast": "clients",
  "payload": {
    "deviceId": 1,
    "conversationId": "conv-xxx",
    "status": "working"  // "idle" | "working" | "permission"
  }
}
```

---

## 히스토리 메시지

### history_request

**방향**: App → Pylon

```json
{
  "type": "history_request",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx",
    "limit": 50,
    "offset": 0
  }
}
```

### history_result

**방향**: Pylon → App

```json
{
  "type": "history_result",
  "payload": {
    "deviceId": 1,
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx",
    "messages": [
      {
        "role": "user",
        "type": "text",
        "content": "안녕",
        "timestamp": 1706180400000
      },
      {
        "role": "assistant",
        "type": "text",
        "content": "안녕하세요!",
        "timestamp": 1706180401000
      },
      {
        "type": "tool_start",
        "toolName": "Read",
        "toolInput": { "file_path": "/path/to/file" },
        "timestamp": 1706180402000
      },
      {
        "type": "tool_complete",
        "toolName": "Read",
        "success": true,
        "output": "file content...",
        "timestamp": 1706180403000
      },
      {
        "type": "result",
        "duration_ms": 5000,
        "usage": {
          "inputTokens": 1000,
          "outputTokens": 500,
          "cacheReadInputTokens": 800
        },
        "timestamp": 1706180410000
      }
    ],
    "offset": 0,
    "totalCount": 100,
    "hasMore": true
  }
}
```

---

## Claude 메시지

### claude_send

**방향**: App → Pylon

```json
{
  "type": "claude_send",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx",
    "message": "안녕하세요"
  }
}
```

### claude_event

**방향**: Pylon → App

모든 Claude 이벤트를 래핑하여 전송

```json
{
  "type": "claude_event",
  "payload": {
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx",
    "event": { ... }  // 아래 이벤트 타입들
  }
}
```

#### 이벤트 타입들

##### userMessage
사용자 메시지 (다른 클라이언트에게 알림)
```json
{
  "type": "userMessage",
  "content": "안녕하세요",
  "timestamp": 1706180400000
}
```

##### init
세션 초기화
```json
{
  "type": "init",
  "session_id": "claude-session-id",
  "model": "claude-sonnet-4-20250514",
  "tools": ["Read", "Write", "Edit", ...]
}
```

##### stateUpdate
상태 업데이트 (UI 상태 표시용)
```json
{
  "type": "stateUpdate",
  "state": {
    "type": "thinking"  // "thinking" | "responding" | "tool"
  },
  "partialText": "..."
}
```

##### text
스트리밍 텍스트 델타
```json
{
  "type": "text",
  "content": "텍스트 일부분"
}
```

##### textComplete
텍스트 완료
```json
{
  "type": "textComplete",
  "text": "전체 텍스트 내용"
}
```

##### toolInfo
도구 실행 시작
```json
{
  "type": "toolInfo",
  "toolName": "Read",
  "input": {
    "file_path": "/path/to/file"
  }
}
```

##### toolComplete
도구 실행 완료
```json
{
  "type": "toolComplete",
  "toolName": "Read",
  "success": true,
  "result": "실행 결과 (최대 1000자)",
  "error": "에러 메시지 (실패 시, 최대 200자)"
}
```

##### permission_request
권한 요청
```json
{
  "type": "permission_request",
  "toolName": "Write",
  "toolInput": {
    "file_path": "/path/to/file",
    "content": "file content"
  },
  "toolUseId": "perm_xxx"
}
```

##### askQuestion
사용자 질문
```json
{
  "type": "askQuestion",
  "toolUseId": "tool-use-id",
  "questions": [
    {
      "question": "어떤 옵션을 선택하시겠습니까?",
      "header": "선택",
      "options": [
        { "label": "옵션 1", "description": "설명 1" },
        { "label": "옵션 2", "description": "설명 2" }
      ],
      "multiSelect": false
    }
  ]
}
```

##### state
상태 변경
```json
{
  "type": "state",
  "state": "idle"  // "idle" | "working" | "permission"
}
```

##### result
처리 완료
```json
{
  "type": "result",
  "subtype": "end_turn",
  "duration_ms": 5000,
  "total_cost_usd": 0.015,
  "num_turns": 3,
  "usage": {
    "inputTokens": 10000,
    "outputTokens": 2000,
    "cacheReadInputTokens": 8000,
    "cacheCreationInputTokens": 0
  }
}
```

##### error
에러
```json
{
  "type": "error",
  "error": "에러 메시지"
}
```

### claude_permission

**방향**: App → Pylon

```json
{
  "type": "claude_permission",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx",
    "toolUseId": "perm_xxx",
    "decision": "allow"  // "allow" | "allowAll" | "deny"
  }
}
```

### claude_answer

**방향**: App → Pylon

```json
{
  "type": "claude_answer",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx",
    "toolUseId": "tool-use-id",
    "answer": "선택한 옵션"
  }
}
```

### claude_control

**방향**: App → Pylon

```json
{
  "type": "claude_control",
  "to": { "deviceId": 1 },
  "payload": {
    "workspaceId": "ws-xxx",
    "conversationId": "conv-xxx",
    "action": "stop"  // "stop" | "new_session" | "clear"
  }
}
```

### claude_set_permission_mode

**방향**: App → Pylon

```json
{
  "type": "claude_set_permission_mode",
  "to": { "deviceId": 1 },
  "payload": {
    "mode": "default"  // "default" | "acceptEdits" | "bypassPermissions"
  }
}
```

---

## Pylon 상태

### pylon_status

**방향**: Pylon → App (브로드캐스트)

```json
{
  "type": "pylon_status",
  "broadcast": "clients",
  "payload": {
    "deviceId": 1,
    "claudeUsage": {
      "totalCostUsd": 0.5,
      "totalInputTokens": 100000,
      "totalOutputTokens": 20000,
      "totalCacheReadTokens": 80000,
      "totalCacheCreationTokens": 0,
      "sessionCount": 50,
      "lastUpdated": "2026-01-25T12:00:00.000Z"
    },
    "deployReady": false
  }
}
```

---

## 배포 메시지

### deploy_prepare

**방향**: App → Pylon

```json
{
  "type": "deploy_prepare",
  "to": { "deviceId": 1 },
  "payload": {
    "relayDeploy": true  // 이 Pylon이 Relay 배포 담당
  }
}
```

### deploy_status

**방향**: Pylon → App

```json
{
  "type": "deploy_status",
  "broadcast": "app",
  "payload": {
    "deviceId": 1,
    "tasks": {
      "git": "done",      // "waiting" | "running" | "done" | "error"
      "apk": "running",
      "exe": "waiting",
      "npm": "waiting",
      "json": "waiting"
    },
    "message": "Git(✓) APK(진행중) EXE(대기)"
  }
}
```

### deploy_log

**방향**: Pylon → App

```json
{
  "type": "deploy_log",
  "broadcast": "app",
  "payload": {
    "deviceId": 1,
    "line": "Building APK...",
    "timestamp": 1706180400000
  }
}
```

### deploy_ready

**방향**: Pylon → App

```json
{
  "type": "deploy_ready",
  "payload": {
    "deviceId": 1,
    "success": true,
    "commitHash": "abc1234",
    "version": "1.0.0",
    "error": "에러 메시지"  // 실패 시
  }
}
```

### deploy_confirm

**방향**: App → Pylon

```json
{
  "type": "deploy_confirm",
  "to": { "deviceId": 1 },
  "payload": {
    "preApproved": true,
    "cancel": false
  }
}
```

### deploy_start

**방향**: Pylon → 모든 Pylon (브로드캐스트)

```json
{
  "type": "deploy_start",
  "broadcast": "all",
  "payload": {
    "commitHash": "abc1234",
    "version": "1.0.0",
    "leadPylonId": 1
  }
}
```

### deploy_go

**방향**: App → Pylon

```json
{
  "type": "deploy_go",
  "to": { "deviceId": 1 }
}
```

### deploy_restart

**방향**: Pylon → 모든 클라이언트

```json
{
  "type": "deploy_restart",
  "broadcast": "all"
}
```

---

## 버전/업데이트 메시지

### version_check_request

**방향**: App → Pylon

```json
{
  "type": "version_check_request",
  "to": { "deviceId": 1 }
}
```

### version_check_result

**방향**: Pylon → App

```json
{
  "type": "version_check_result",
  "payload": {
    "version": "1.0.0",
    "commit": "abc1234",
    "buildTime": "20260125120000",
    "apkUrl": "https://...",
    "exeUrl": "https://...",
    "error": null
  }
}
```

### app_update_request

**방향**: App → Pylon

```json
{
  "type": "app_update_request",
  "to": { "deviceId": 1 }
}
```

### app_update_result

**방향**: Pylon → App

```json
{
  "type": "app_update_result",
  "payload": {
    "success": true,
    "version": "1.0.0",
    "commit": "abc1234",
    "apkUrl": "https://...",
    "exeUrl": "https://..."
  }
}
```

---

## 기타 메시지

### bug_report

**방향**: App → Pylon

```json
{
  "type": "bug_report",
  "to": { "deviceId": 1 },
  "payload": {
    "message": "버그 내용...",
    "timestamp": "2026-01-25T12:00:00.000Z"
  }
}
```

### folder_list

**방향**: App → Pylon

```json
{
  "type": "folder_list",
  "to": { "deviceId": 1 },
  "payload": {
    "path": "C:\\"
  }
}
```

### folder_list_result

**방향**: Pylon → App

```json
{
  "type": "folder_list_result",
  "payload": {
    "deviceId": 1,
    "path": "C:\\",
    "folders": ["Users", "Program Files", ...],
    "success": true
  }
}
```

---

## 자동 권한 처리

ClaudeManager의 자동 허용/거부 규칙:

### 자동 허용 도구

```javascript
autoAllowTools = ['Read', 'Glob', 'Grep', 'WebSearch', 'WebFetch', 'TodoWrite']
```

### 자동 거부 패턴

| 도구 | 패턴 | 이유 |
|------|------|------|
| Edit | `\.(env\|secret\|credentials\|password)` | Protected file |
| Write | `\.(env\|secret\|credentials\|password)` | Protected file |
| Bash | `rm -rf /`, `format`, `shutdown` 등 | Dangerous command |

### 권한 모드

| 모드 | 동작 |
|------|------|
| `default` | 자동 허용/거부 규칙 적용 |
| `acceptEdits` | Edit, Write, Bash, NotebookEdit 자동 허용 |
| `bypassPermissions` | 모든 도구 자동 허용 (AskUserQuestion 제외) |

---

## 관련 문서

- [architecture.md](./architecture.md) - 시스템 아키텍처
- [device-id.md](./device-id.md) - Device ID 체계
