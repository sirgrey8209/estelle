import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/relay_config.dart';

typedef MessageHandler = void Function(Map<String, dynamic> data);

class RelayService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  bool _isReconnecting = false;
  int? _deviceId;  // Relay에서 발급받은 deviceId

  final _connectionController = StreamController<bool>.broadcast();
  final _authController = StreamController<bool>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get authStream => _authController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  int? get deviceId => _deviceId;

  void connect() {
    if (_isConnected || _isReconnecting) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(RelayConfig.relayUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _isConnected = true;
      _connectionController.add(true);

      // Send auth
      _sendAuth();
    } catch (e) {
      print('Connection error: $e');
      _scheduleReconnect();
    }
  }

  void _sendAuth() {
    send({
      'type': 'auth',
      'payload': {
        'deviceType': RelayConfig.deviceType,
      },
    });
  }

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;

      // Handle auth result
      if (json['type'] == 'auth_result') {
        final payload = json['payload'] as Map<String, dynamic>?;
        if (payload?['success'] == true) {
          // Relay에서 발급받은 deviceId 저장
          final device = payload?['device'] as Map<String, dynamic>?;
          _deviceId = device?['deviceId'] as int?;
          print('Assigned deviceId: $_deviceId');

          _isAuthenticated = true;
          _authController.add(true);
        } else {
          print('Auth failed: ${payload?['error']}');
        }
        return;
      }

      // 디버그: deploy_ 메시지 로깅
      final type = json['type'] as String?;
      if (type != null && type.startsWith('deploy_')) {
        print('[RELAY] Received: $type');
      }

      _messageController.add(json);
    } catch (e) {
      print('Message parse error: $e');
    }
  }

  void _onError(dynamic error) {
    print('WebSocket error: $error');
    _handleDisconnect();
  }

  void _onDone() {
    print('WebSocket closed');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isAuthenticated = false;
    _deviceId = null;
    _connectionController.add(false);
    _authController.add(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isReconnecting) return;
    _isReconnecting = true;

    Future.delayed(const Duration(seconds: 3), () {
      _isReconnecting = false;
      if (!_isConnected) {
        connect();
      }
    });
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _isAuthenticated = false;
    _deviceId = null;
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _authController.close();
    _messageController.close();
  }

  // ============ Workspace Management ============

  void requestWorkspaceList() {
    send({
      'type': 'workspace_list',
      'broadcast': 'pylons',
    });
  }

  void createWorkspace(int deviceId, String name, String workingDir) {
    send({
      'type': 'workspace_create',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'name': name, 'workingDir': workingDir},
    });
  }

  void deleteWorkspace(int deviceId, String workspaceId) {
    send({
      'type': 'workspace_delete',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'workspaceId': workspaceId},
    });
  }

  void renameWorkspace(int deviceId, String workspaceId, String newName) {
    send({
      'type': 'workspace_rename',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'workspaceId': workspaceId, 'newName': newName},
    });
  }

  void switchWorkspace(int deviceId, String workspaceId, {String? conversationId}) {
    send({
      'type': 'workspace_switch',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        if (conversationId != null) 'conversationId': conversationId,
      },
    });
  }

  // ============ Conversation Management ============

  void createConversation(int deviceId, String workspaceId, {String? name, String skillType = 'general'}) {
    send({
      'type': 'conversation_create',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        'skillType': skillType,
        if (name != null) 'name': name,
      },
    });
  }

  void deleteConversation(int deviceId, String workspaceId, String conversationId) {
    send({
      'type': 'conversation_delete',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        'conversationId': conversationId,
      },
    });
  }

  void renameConversation(int deviceId, String workspaceId, String conversationId, String newName) {
    send({
      'type': 'conversation_rename',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        'conversationId': conversationId,
        'newName': newName,
      },
    });
  }

  void selectConversation(int deviceId, String workspaceId, String conversationId) {
    send({
      'type': 'conversation_select',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        'conversationId': conversationId,
      },
    });
  }

  // ============ Claude Control ============

  void sendClaudeMessage(int deviceId, String workspaceId, String conversationId, String message) {
    send({
      'type': 'claude_send',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        'conversationId': conversationId,
        'message': message,
      },
    });
  }

  void sendClaudeControl(int deviceId, String workspaceId, String conversationId, String action) {
    send({
      'type': 'claude_control',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        'conversationId': conversationId,
        'action': action,
      },
    });
  }

  void sendClaudePermission(int deviceId, String workspaceId, String conversationId, String toolUseId, String decision) {
    send({
      'type': 'claude_permission',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        'conversationId': conversationId,
        'toolUseId': toolUseId,
        'decision': decision,
      },
    });
  }

  void sendClaudeAnswer(int deviceId, String workspaceId, String conversationId, String toolUseId, dynamic answer) {
    send({
      'type': 'claude_answer',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        'conversationId': conversationId,
        'toolUseId': toolUseId,
        'answer': answer,
      },
    });
  }

  /// 퍼미션 모드 변경 (특정 대화에 적용)
  /// [deviceId] - Pylon deviceId
  /// [conversationId] - 대화 ID
  /// [mode] - 'default', 'acceptEdits', 'bypassPermissions'
  void setPermissionMode(int deviceId, String conversationId, String mode) {
    send({
      'type': 'claude_set_permission_mode',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'conversationId': conversationId, 'mode': mode},
    });
  }

  // ============ History Pagination ============

  void requestHistory(int deviceId, String workspaceId, String conversationId, {int limit = 50, int offset = 0}) {
    send({
      'type': 'history_request',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        'conversationId': conversationId,
        'limit': limit,
        'offset': offset,
      },
    });
  }

  // ============ Deploy ============

  /// 배포 준비 요청 (주도 Pylon에게만)
  void sendDeployPrepare(int pylonDeviceId) {
    send({
      'type': 'deploy_prepare',
      'to': {'deviceId': pylonDeviceId, 'deviceType': 'pylon'},
      'payload': {'relayDeploy': true},
    });
  }

  /// 배포 확인 (사전 승인 / 취소 토글)
  void sendDeployConfirm(int pylonDeviceId, {bool preApproved = false, bool cancel = false}) {
    send({
      'type': 'deploy_confirm',
      'to': {'deviceId': pylonDeviceId, 'deviceType': 'pylon'},
      'payload': {
        'preApproved': preApproved,
        'cancel': cancel,
      },
    });
  }

  /// 배포 실행 요청 (모든 Pylon + 앱에 브로드캐스트)
  void sendDeployGo() {
    send({
      'type': 'deploy_go',
      'broadcast': 'all',
      'payload': {},
    });
  }

  // ============ Claude Usage ============

  void requestClaudeUsage() {
    send({
      'type': 'claude_usage_request',
      'broadcast': 'pylons',
    });
  }

  // ============ Version Check ============

  void requestVersionCheck() {
    send({
      'type': 'version_check_request',
      'broadcast': 'pylons',
    });
  }

  void requestAppUpdate(int pylonDeviceId) {
    send({
      'type': 'app_update_request',
      'to': {'deviceId': pylonDeviceId, 'deviceType': 'pylon'},
      'payload': {},
    });
  }

  // ============ Folder Management ============

  void requestFolderList(int deviceId, {String? path}) {
    send({
      'type': 'folder_list',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        if (path != null) 'path': path,
      },
    });
  }

  void createFolder(int deviceId, String parentPath, String name) {
    send({
      'type': 'folder_create',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'path': parentPath, 'name': name},
    });
  }

  void renameFolder(int deviceId, String folderPath, String newName) {
    send({
      'type': 'folder_rename',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'path': folderPath, 'newName': newName},
    });
  }

  // ============ Task Management ============

  void requestTaskList(int deviceId, String workspaceId) {
    send({
      'type': 'task_list',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'workspaceId': workspaceId},
    });
  }

  void requestTaskGet(int deviceId, String workspaceId, String taskId) {
    send({
      'type': 'task_get',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'workspaceId': workspaceId, 'taskId': taskId},
    });
  }

  void updateTaskStatus(int deviceId, String workspaceId, String taskId, String status, {String? error}) {
    send({
      'type': 'task_status',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'workspaceId': workspaceId,
        'taskId': taskId,
        'status': status,
        if (error != null) 'error': error,
      },
    });
  }

  // ============ Worker Management ============

  void requestWorkerStatus(int deviceId, String workspaceId) {
    send({
      'type': 'worker_status',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'workspaceId': workspaceId},
    });
  }

  void startWorker(int deviceId, String workspaceId) {
    send({
      'type': 'worker_start',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'workspaceId': workspaceId},
    });
  }

  void stopWorker(int deviceId, String workspaceId) {
    send({
      'type': 'worker_stop',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'workspaceId': workspaceId},
    });
  }

  // ============ Bug Report ============

  void sendBugReport({
    required String message,
    String? conversationId,
    String? workspaceId,
  }) {
    send({
      'type': 'bug_report',
      'broadcast': 'pylons',
      'payload': {
        'message': message,
        'conversationId': conversationId,
        'workspaceId': workspaceId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }

  // ============ Debug Log ============

  /// 모바일 디버그 로그를 Pylon으로 전송
  void sendDebugLog(String tag, String message, [Map<String, dynamic>? extra]) {
    send({
      'type': 'debug_log',
      'broadcast': 'pylons',
      'payload': {
        'tag': tag,
        'message': message,
        'extra': extra,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }
}

// Singleton instance
final relayService = RelayService();
