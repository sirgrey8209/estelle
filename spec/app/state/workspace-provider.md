# Workspace Provider

> 워크스페이스와 선택 상태를 관리하는 Provider

## 위치

`lib/state/providers/workspace_provider.dart`

---

## 역할

- Pylon별 워크스페이스 목록 관리
- 선택된 항목 (대화/태스크) 관리
- 워크스페이스/대화 CRUD 요청
- 마지막 선택 항목 저장/복원

---

## Provider 목록

### pylonWorkspacesProvider

Pylon별 워크스페이스 목록

```dart
StateNotifierProvider<PylonWorkspacesNotifier, Map<int, PylonWorkspaces>>
```

| 키 | 타입 | 설명 |
|----|------|------|
| deviceId | `int` | Pylon Device ID |
| value | `PylonWorkspaces` | Pylon 정보 + 워크스페이스 목록 |

### selectedItemProvider

현재 선택된 항목

```dart
StateNotifierProvider<SelectedItemNotifier, SelectedItem?>
```

### selectedWorkspaceProvider

선택된 워크스페이스 (derived)

```dart
Provider<WorkspaceInfo?>
```

### selectedConversationProvider

선택된 대화 (derived)

```dart
Provider<ConversationInfo?>
```

### selectedTaskProvider

선택된 태스크 (derived)

```dart
Provider<TaskInfo?>
```

### allWorkspacesProvider

모든 워크스페이스 목록 (derived)

```dart
Provider<List<WorkspaceInfo>>
```

### pylonListWorkspacesProvider

Pylon 목록 (deviceId 순 정렬)

```dart
Provider<List<PylonWorkspaces>>
```

### folderListProvider

폴더 목록 (새 워크스페이스 다이얼로그용)

```dart
StateNotifierProvider<FolderListNotifier, FolderListState>
```

### activeActionItemProvider

현재 편집 모드가 열린 항목 ID

```dart
StateProvider<String?>
```

---

## 데이터 구조

### SelectedItem

```dart
class SelectedItem {
  final SelectedItemType type;  // conversation | task
  final String workspaceId;
  final String itemId;          // conversationId 또는 taskId
  final int deviceId;

  bool get isConversation => type == SelectedItemType.conversation;
  bool get isTask => type == SelectedItemType.task;
}
```

### PylonWorkspaces

```dart
class PylonWorkspaces {
  final int deviceId;
  final String name;       // "Selene", "Stella"
  final String icon;       // "🌙", "⭐"
  final List<WorkspaceInfo> workspaces;
}
```

### FolderListState

```dart
class FolderListState {
  final bool isLoading;
  final String path;           // 현재 경로
  final List<String> folders;  // 하위 폴더 목록
  final String? error;
}
```

---

## 메서드

### PylonWorkspacesNotifier

| 메서드 | 설명 |
|--------|------|
| `requestWorkspaceList()` | 워크스페이스 목록 요청 |
| `createWorkspace(deviceId, name, workingDir)` | 새 워크스페이스 생성 |
| `deleteWorkspace(deviceId, workspaceId)` | 워크스페이스 삭제 |
| `renameWorkspace(deviceId, workspaceId, newName)` | 워크스페이스 이름 변경 |
| `createConversation(deviceId, workspaceId, name?, skillType)` | 새 대화 생성 |
| `deleteConversation(deviceId, workspaceId, conversationId)` | 대화 삭제 |
| `renameConversation(deviceId, workspaceId, conversationId, newName)` | 대화 이름 변경 |

### SelectedItemNotifier

| 메서드 | 설명 |
|--------|------|
| `selectConversation(deviceId, workspaceId, conversationId)` | 대화 선택 |
| `selectTask(deviceId, workspaceId, taskId)` | 태스크 선택 |
| `clear()` | 선택 해제 |

### FolderListNotifier

| 메서드 | 설명 |
|--------|------|
| `requestFolderList(deviceId, path?)` | 폴더 목록 요청 |
| `createFolder(deviceId, parentPath, name)` | 폴더 생성 |
| `renameFolder(deviceId, folderPath, newName)` | 폴더 이름 변경 |

---

## 메시지 핸들링

| 메시지 타입 | 처리 |
|-------------|------|
| `workspace_list_result` | 워크스페이스 목록 업데이트 + 자동 선택 |
| `workspace_create_result` | 새 워크스페이스 추가 + 선택 |
| `conversation_create_result` | 새 대화 추가 + 선택 |
| `conversation_status` | 대화 상태 업데이트 (working/idle 등) |
| `task_list_result` | 태스크 목록 업데이트 |
| `folder_list_result` | 폴더 목록 업데이트 |

---

## 자동 선택 로직

앱 시작 시 자동 선택 순서:

1. **SharedPreferences에서 마지막 선택 항목 복원**
2. **Pylon의 activeWorkspaceId/activeConversationId 사용**
3. **첫 번째 워크스페이스의 첫 번째 대화 선택**

```dart
Future<void> _tryAutoSelect(...) async {
  // 1. 이미 선택된 항목 있으면 종료
  if (currentSelected != null) return;

  // 2. 마지막 선택 항목 복원
  final lastItem = await _loadLastWorkspace();
  if (lastItem != null) { ... }

  // 3. Pylon의 활성 항목 사용
  if (activeWorkspaceId != null) { ... }

  // 4. 첫 번째 대화 선택
  if (newWorkspaces.isNotEmpty) { ... }
}
```

---

## 로컬 저장소

### 마지막 선택 항목

`SharedPreferences` 키: `estelle_last_workspace`

```json
{
  "workspaceId": "ws-uuid",
  "itemType": "conversation",
  "itemId": "conv-uuid"
}
```

---

## 관련 문서

- [claude-provider.md](./claude-provider.md) - Claude 상태 관리
- [relay-provider.md](./relay-provider.md) - Relay 연결 관리
- [../components/workspace-sidebar.md](../components/workspace-sidebar.md) - 사이드바 컴포넌트
