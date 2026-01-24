import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/workspace_info.dart';
import '../../data/services/relay_service.dart';
import 'relay_provider.dart';

const _lastWorkspaceKey = 'estelle_last_workspace';

/// 선택 가능한 항목 타입
enum SelectedItemType { conversation, task }

/// 현재 선택된 항목 (대화 또는 태스크)
class SelectedItem {
  final SelectedItemType type;
  final String workspaceId;
  final String itemId; // conversationId 또는 taskId
  final int deviceId;

  SelectedItem({
    required this.type,
    required this.workspaceId,
    required this.itemId,
    required this.deviceId,
  });

  bool get isConversation => type == SelectedItemType.conversation;
  bool get isTask => type == SelectedItemType.task;
}

/// Pylon별 워크스페이스 상태
class PylonWorkspacesNotifier extends StateNotifier<Map<int, PylonWorkspaces>> {
  final RelayService _relay;
  final Ref _ref;
  final Set<int> _receivedPylons = {};
  bool _autoSelectDone = false;

  PylonWorkspacesNotifier(this._relay, this._ref) : super({}) {
    _relay.messageStream.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final payload = data['payload'] as Map<String, dynamic>?;

    switch (type) {
      case 'workspace_list_result':
        _handleWorkspaceListResult(payload);
        break;
      case 'workspace_create_result':
        _handleWorkspaceCreateResult(payload);
        break;
      case 'task_list_result':
        _handleTaskListResult(payload);
        break;
      case 'folder_list_result':
        _handleFolderListResult(payload);
        break;
    }
  }

  void _handleWorkspaceListResult(Map<String, dynamic>? payload) async {
    if (payload == null) return;

    final deviceId = payload['deviceId'] as int?;
    if (deviceId == null) return;

    final deviceInfo = payload['deviceInfo'] as Map<String, dynamic>?;
    final deviceName = deviceInfo?['name'] as String? ?? 'Device $deviceId';
    final deviceIcon = deviceInfo?['icon'] as String? ?? '';

    final workspacesRaw = payload['workspaces'] as List<dynamic>?;
    final activeWorkspaceId = payload['activeWorkspaceId'] as String?;
    final activeConversationId = payload['activeConversationId'] as String?;

    final workspaces = workspacesRaw?.map((w) {
      final ws = w as Map<String, dynamic>;
      return WorkspaceInfo.fromJson(
        ws,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceIcon: deviceIcon,
      ).copyWith(
        isActive: ws['workspaceId'] == activeWorkspaceId,
      );
    }).toList() ?? [];

    state = {
      ...state,
      deviceId: PylonWorkspaces(
        deviceId: deviceId,
        name: deviceName,
        icon: deviceIcon,
        workspaces: workspaces,
      ),
    };

    // 자동 선택
    _receivedPylons.add(deviceId);
    if (!_autoSelectDone && workspaces.isNotEmpty) {
      await _tryAutoSelect(workspaces, activeWorkspaceId, activeConversationId);
    }
  }

  Future<void> _tryAutoSelect(
    List<WorkspaceInfo> newWorkspaces,
    String? activeWorkspaceId,
    String? activeConversationId,
  ) async {
    final currentSelected = _ref.read(selectedItemProvider);
    if (currentSelected != null) {
      _autoSelectDone = true;
      return;
    }

    // 마지막 선택 항목 확인
    final lastItem = await _loadLastWorkspace();
    if (lastItem != null) {
      final ws = newWorkspaces.firstWhere(
        (w) => w.workspaceId == lastItem['workspaceId'],
        orElse: () => WorkspaceInfo(
          deviceId: 0,
          deviceName: '',
          deviceIcon: '',
          workspaceId: '',
          name: '',
          workingDir: '',
          conversations: [],
          tasks: [],
        ),
      );
      if (ws.workspaceId.isNotEmpty) {
        final itemType = lastItem['itemType'] as String?;
        final itemId = lastItem['itemId'] as String?;

        if (itemType == 'task' && itemId != null) {
          _ref.read(selectedItemProvider.notifier).selectTask(
            ws.deviceId, ws.workspaceId, itemId,
          );
        } else if (itemId != null) {
          _ref.read(selectedItemProvider.notifier).selectConversation(
            ws.deviceId, ws.workspaceId, itemId,
          );
        } else if (ws.conversations.isNotEmpty) {
          _ref.read(selectedItemProvider.notifier).selectConversation(
            ws.deviceId, ws.workspaceId, ws.conversations.first.conversationId,
          );
        }
        _autoSelectDone = true;
        return;
      }
    }

    // 활성 워크스페이스/대화 선택
    if (activeWorkspaceId != null) {
      final ws = newWorkspaces.firstWhere(
        (w) => w.workspaceId == activeWorkspaceId,
        orElse: () => newWorkspaces.first,
      );
      if (activeConversationId != null) {
        _ref.read(selectedItemProvider.notifier).selectConversation(
          ws.deviceId, ws.workspaceId, activeConversationId,
        );
      } else if (ws.conversations.isNotEmpty) {
        _ref.read(selectedItemProvider.notifier).selectConversation(
          ws.deviceId, ws.workspaceId, ws.conversations.first.conversationId,
        );
      }
      _autoSelectDone = true;
    } else if (newWorkspaces.isNotEmpty) {
      // 첫 번째 워크스페이스의 첫 번째 대화 선택
      final ws = newWorkspaces.first;
      if (ws.conversations.isNotEmpty) {
        _ref.read(selectedItemProvider.notifier).selectConversation(
          ws.deviceId, ws.workspaceId, ws.conversations.first.conversationId,
        );
        _autoSelectDone = true;
      }
    }
  }

  Future<Map<String, dynamic>?> _loadLastWorkspace() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_lastWorkspaceKey);
      if (json != null) {
        return jsonDecode(json) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  static Future<void> saveLastWorkspace({
    required String workspaceId,
    required String itemType,
    required String itemId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastWorkspaceKey, jsonEncode({
        'workspaceId': workspaceId,
        'itemType': itemType,
        'itemId': itemId,
      }));
    } catch (e) {
      // ignore
    }
  }

  void _handleWorkspaceCreateResult(Map<String, dynamic>? payload) {
    if (payload == null) return;
    if (payload['success'] != true) return;

    final deviceId = payload['deviceId'] as int?;
    final workspaceData = payload['workspace'] as Map<String, dynamic>?;
    final conversationData = payload['conversation'] as Map<String, dynamic>?;

    if (deviceId == null || workspaceData == null) return;

    final pylon = state[deviceId];
    if (pylon == null) return;

    final newWorkspace = WorkspaceInfo.fromJson(
      workspaceData,
      deviceId: deviceId,
      deviceName: pylon.name,
      deviceIcon: pylon.icon,
    );

    // 새 워크스페이스 바로 선택
    if (conversationData != null) {
      final convId = conversationData['conversationId'] as String?;
      if (convId != null) {
        _ref.read(selectedItemProvider.notifier).selectConversation(
          deviceId, newWorkspace.workspaceId, convId,
        );
        saveLastWorkspace(
          workspaceId: newWorkspace.workspaceId,
          itemType: 'conversation',
          itemId: convId,
        );
      }
    }
  }

  void _handleTaskListResult(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final deviceId = payload['deviceId'] as int?;
    final workspaceId = payload['workspaceId'] as String?;
    final tasksRaw = payload['tasks'] as List<dynamic>?;

    if (deviceId == null || workspaceId == null) return;

    final pylon = state[deviceId];
    if (pylon == null) return;

    final tasks = tasksRaw?.map((t) => TaskInfo.fromJson(t as Map<String, dynamic>)).toList() ?? [];

    final updatedWorkspaces = pylon.workspaces.map((ws) {
      if (ws.workspaceId == workspaceId) {
        return ws.copyWith(tasks: tasks);
      }
      return ws;
    }).toList();

    state = {
      ...state,
      deviceId: pylon.copyWith(workspaces: updatedWorkspaces),
    };
  }

  void _handleFolderListResult(Map<String, dynamic>? payload) {
    // 폴더 목록은 다이얼로그에서 직접 처리
    // 여기서는 별도 처리 없음
  }

  void requestWorkspaceList() {
    _relay.requestWorkspaceList();
  }

  void createWorkspace(int deviceId, String name, String workingDir) {
    _relay.createWorkspace(deviceId, name, workingDir);
  }

  void deleteWorkspace(int deviceId, String workspaceId) {
    _relay.deleteWorkspace(deviceId, workspaceId);
  }

  void createConversation(int deviceId, String workspaceId, {String? name}) {
    _relay.createConversation(deviceId, workspaceId, name: name);
  }
}

extension PylonWorkspacesExtension on PylonWorkspaces {
  PylonWorkspaces copyWith({
    int? deviceId,
    String? name,
    String? icon,
    List<WorkspaceInfo>? workspaces,
  }) {
    return PylonWorkspaces(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      workspaces: workspaces ?? this.workspaces,
    );
  }
}

final pylonWorkspacesProvider = StateNotifierProvider<PylonWorkspacesNotifier, Map<int, PylonWorkspaces>>((ref) {
  final relay = ref.watch(relayServiceProvider);
  return PylonWorkspacesNotifier(relay, ref);
});

/// 모든 워크스페이스 목록
final allWorkspacesProvider = Provider<List<WorkspaceInfo>>((ref) {
  final pylons = ref.watch(pylonWorkspacesProvider);
  return pylons.values.expand((p) => p.workspaces).toList();
});

/// Pylon 목록 (워크스페이스 기반)
final pylonListWorkspacesProvider = Provider<List<PylonWorkspaces>>((ref) {
  final pylons = ref.watch(pylonWorkspacesProvider);
  return pylons.values.toList()..sort((a, b) => a.deviceId.compareTo(b.deviceId));
});

/// 선택된 항목 상태
class SelectedItemNotifier extends StateNotifier<SelectedItem?> {
  SelectedItemNotifier() : super(null);

  void selectConversation(int deviceId, String workspaceId, String conversationId) {
    state = SelectedItem(
      type: SelectedItemType.conversation,
      workspaceId: workspaceId,
      itemId: conversationId,
      deviceId: deviceId,
    );
    PylonWorkspacesNotifier.saveLastWorkspace(
      workspaceId: workspaceId,
      itemType: 'conversation',
      itemId: conversationId,
    );
  }

  void selectTask(int deviceId, String workspaceId, String taskId) {
    state = SelectedItem(
      type: SelectedItemType.task,
      workspaceId: workspaceId,
      itemId: taskId,
      deviceId: deviceId,
    );
    PylonWorkspacesNotifier.saveLastWorkspace(
      workspaceId: workspaceId,
      itemType: 'task',
      itemId: taskId,
    );
  }

  void clear() {
    state = null;
  }
}

final selectedItemProvider = StateNotifierProvider<SelectedItemNotifier, SelectedItem?>((ref) {
  return SelectedItemNotifier();
});

/// 선택된 워크스페이스
final selectedWorkspaceProvider = Provider<WorkspaceInfo?>((ref) {
  final selectedItem = ref.watch(selectedItemProvider);
  if (selectedItem == null) return null;

  final pylons = ref.watch(pylonWorkspacesProvider);
  final pylon = pylons[selectedItem.deviceId];
  if (pylon == null) return null;

  return pylon.workspaces.firstWhere(
    (ws) => ws.workspaceId == selectedItem.workspaceId,
    orElse: () => WorkspaceInfo(
      deviceId: 0,
      deviceName: '',
      deviceIcon: '',
      workspaceId: '',
      name: '',
      workingDir: '',
      conversations: [],
      tasks: [],
    ),
  );
});

/// 선택된 대화 정보
final selectedConversationProvider = Provider<ConversationInfo?>((ref) {
  final selectedItem = ref.watch(selectedItemProvider);
  if (selectedItem == null || !selectedItem.isConversation) return null;

  final workspace = ref.watch(selectedWorkspaceProvider);
  if (workspace == null) return null;

  return workspace.conversations.firstWhere(
    (c) => c.conversationId == selectedItem.itemId,
    orElse: () => ConversationInfo(conversationId: '', name: ''),
  );
});

/// 선택된 태스크 정보
final selectedTaskProvider = Provider<TaskInfo?>((ref) {
  final selectedItem = ref.watch(selectedItemProvider);
  if (selectedItem == null || !selectedItem.isTask) return null;

  final workspace = ref.watch(selectedWorkspaceProvider);
  if (workspace == null) return null;

  return workspace.tasks.firstWhere(
    (t) => t.id == selectedItem.itemId,
    orElse: () => TaskInfo(id: '', title: ''),
  );
});

/// 폴더 목록 상태 (새 워크스페이스 다이얼로그용)
class FolderListNotifier extends StateNotifier<FolderListState> {
  final RelayService _relay;

  FolderListNotifier(this._relay) : super(FolderListState.initial()) {
    _relay.messageStream.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> data) {
    if (data['type'] != 'folder_list_result') return;

    final payload = data['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final success = payload['success'] as bool? ?? false;
    final path = payload['path'] as String? ?? '';
    final folders = (payload['folders'] as List<dynamic>?)
        ?.map((f) => f as String)
        .toList() ?? [];
    final error = payload['error'] as String?;

    state = FolderListState(
      isLoading: false,
      path: path,
      folders: folders,
      error: success ? null : error,
    );
  }

  void requestFolderList(int deviceId, {String? path}) {
    state = state.copyWith(isLoading: true, error: null);
    _relay.requestFolderList(deviceId, path: path);
  }

  void createFolder(int deviceId, String parentPath, String name) {
    _relay.createFolder(deviceId, parentPath, name);
  }

  void renameFolder(int deviceId, String folderPath, String newName) {
    _relay.renameFolder(deviceId, folderPath, newName);
  }
}

class FolderListState {
  final bool isLoading;
  final String path;
  final List<String> folders;
  final String? error;

  FolderListState({
    required this.isLoading,
    required this.path,
    required this.folders,
    this.error,
  });

  factory FolderListState.initial() => FolderListState(
    isLoading: false,
    path: 'C:\\workspace',
    folders: [],
  );

  FolderListState copyWith({
    bool? isLoading,
    String? path,
    List<String>? folders,
    String? error,
  }) {
    return FolderListState(
      isLoading: isLoading ?? this.isLoading,
      path: path ?? this.path,
      folders: folders ?? this.folders,
      error: error,
    );
  }
}

final folderListProvider = StateNotifierProvider<FolderListNotifier, FolderListState>((ref) {
  final relay = ref.watch(relayServiceProvider);
  return FolderListNotifier(relay);
});
