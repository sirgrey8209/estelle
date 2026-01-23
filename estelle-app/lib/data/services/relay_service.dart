import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/desk_info.dart';
import '../models/claude_message.dart';
import '../models/pending_request.dart';
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
          // Request desk list
          requestDeskList();
        } else {
          print('Auth failed: ${payload?['error']}');
        }
        return;
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

  // ============ Desk Management ============

  void requestDeskList() {
    send({
      'type': 'desk_list',
      'broadcast': 'pylons',
    });
  }

  void switchDesk(int deviceId, String deskId) {
    send({
      'type': 'desk_switch',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'deskId': deskId},
    });
  }

  void requestDeskSync(int deviceId, String deskId) {
    send({
      'type': 'desk_sync',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'deskId': deskId},
    });
  }

  /// 데스크 선택 알림 (선택적 이벤트 라우팅용)
  /// Pylon에게 이 클라이언트가 해당 데스크를 보고 있음을 알림
  void selectDesk(int deviceId, String deskId) {
    send({
      'type': 'desk_select',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'deskId': deskId},
    });
    // 선택 후 sync도 요청
    requestDeskSync(deviceId, deskId);
  }

  void createDesk(int deviceId, String name, String workingDir) {
    send({
      'type': 'desk_create',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'name': name, 'workingDir': workingDir},
    });
  }

  void renameDesk(int deviceId, String deskId, String newName) {
    send({
      'type': 'desk_rename',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'deskId': deskId, 'newName': newName},
    });
  }

  void deleteDesk(int deviceId, String deskId) {
    send({
      'type': 'desk_delete',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'deskId': deskId},
    });
  }

  // ============ Claude Control ============

  void sendClaudeMessage(int deviceId, String deskId, String message) {
    send({
      'type': 'claude_send',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'deskId': deskId, 'message': message},
    });
  }

  void sendClaudePermission(int deviceId, String deskId, String toolUseId, String decision) {
    send({
      'type': 'claude_permission',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'deskId': deskId,
        'toolUseId': toolUseId,
        'decision': decision,
      },
    });
  }

  void sendClaudeAnswer(int deviceId, String deskId, String toolUseId, dynamic answer) {
    send({
      'type': 'claude_answer',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'deskId': deskId,
        'toolUseId': toolUseId,
        'answer': answer,
      },
    });
  }

  void sendClaudeControl(int deviceId, String deskId, String action) {
    send({
      'type': 'claude_control',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {'deskId': deskId, 'action': action},
    });
  }

  // ============ History Pagination ============

  void requestHistory(int deviceId, String deskId, {int limit = 50, int offset = 0}) {
    send({
      'type': 'history_request',
      'to': {'deviceId': deviceId, 'deviceType': 'pylon'},
      'payload': {
        'deskId': deskId,
        'limit': limit,
        'offset': offset,
      },
    });
  }

  // ============ Deploy ============

  /// 배포 준비 요청 (주도 Pylon에게만)
  /// [pylonDeviceId] - 주도 Pylon의 deviceId
  void sendDeployPrepare(int pylonDeviceId) {
    send({
      'type': 'deploy_prepare',
      'to': {'deviceId': pylonDeviceId, 'deviceType': 'pylon'},
      'payload': {'relayDeploy': true},
    });
  }

  /// 배포 확인 (사전 승인 / 취소 토글)
  /// [pylonDeviceId] - 주도 Pylon의 deviceId
  /// [preApproved] - 사전 승인 여부
  /// [cancel] - 취소 여부
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
}

// Singleton instance
final relayService = RelayService();
