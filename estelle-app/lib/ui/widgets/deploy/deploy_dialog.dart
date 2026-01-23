import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/colors.dart';
import '../../../state/providers/relay_provider.dart';
import '../../../state/providers/desk_provider.dart';

/// 배포 상태
enum DeployPhase {
  idle,       // 초기: Pylon 선택
  building,   // P1 빌드 중 (사전 승인 가능)
  buildReady, // P1 빌드 완료, 승인 대기
  preparing,  // 다른 Pylon 준비 중
  ready,      // 모든 준비 완료, GO 대기
  deploying,  // 배포 실행 중
  error,      // 오류
}

/// 배포 다이얼로그
class DeployDialog extends ConsumerStatefulWidget {
  const DeployDialog({super.key});

  @override
  ConsumerState<DeployDialog> createState() => _DeployDialogState();
}

class _DeployDialogState extends ConsumerState<DeployDialog> {
  DeployPhase _phase = DeployPhase.idle;
  String _statusMessage = '배포할 Pylon을 선택하세요';
  String? _errorMessage;

  int? _selectedPylonId;
  bool _confirmed = false;  // 승인 여부 (토글)

  // 빌드 태스크 상태: git, apk, exe, npm, json
  Map<String, String> _buildTasks = {};
  String? _commitHash;
  String? _version;

  // 다른 Pylon ack 수
  int _pylonAckCount = 0;

  DateTime? _startTime;
  Timer? _progressTimer;
  int _estimatedSeconds = 180;

  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadBuildTimeStats();
    _listenToMessages();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBuildTimeStats() async {
    final prefs = await SharedPreferences.getInstance();
    final times = prefs.getStringList('deploy_times') ?? [];

    if (times.isNotEmpty) {
      final recentTimes = times.take(3).map((t) => int.tryParse(t) ?? 180).toList();
      _estimatedSeconds = (recentTimes.reduce((a, b) => a + b) / recentTimes.length).round();
    }
  }

  Future<void> _saveBuildTime(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final times = prefs.getStringList('deploy_times') ?? [];
    times.insert(0, seconds.toString());
    if (times.length > 5) times.removeLast();
    await prefs.setStringList('deploy_times', times);
  }

  void _listenToMessages() {
    _messageSubscription = ref.read(relayServiceProvider).messageStream.listen((data) {
      final type = data['type'] as String?;
      final payload = data['payload'] as Map<String, dynamic>?;

      switch (type) {
        case 'deploy_status':
          _handleDeployStatus(payload);
          break;
        case 'deploy_ready':
          _handleDeployReady(payload);
          break;
        case 'deploy_ack_received':
          _handleAckReceived(payload);
          break;
        case 'deploy_restarting':
          _handleDeployRestarting(payload);
          break;
        case 'deploy_error':
          _handleDeployError(payload);
          break;
      }
    });
  }

  void _handleDeployStatus(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final tasks = payload['tasks'] as Map<String, dynamic>?;
    final message = payload['message'] as String?;

    setState(() {
      if (tasks != null) {
        _buildTasks = tasks.map((k, v) => MapEntry(k, v.toString()));
      }
      if (message != null) {
        _statusMessage = message;
      }
    });
  }

  void _handleDeployReady(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final success = payload['success'] as bool? ?? false;
    final error = payload['error'] as String?;
    final commitHash = payload['commitHash'] as String?;
    final version = payload['version'] as String?;

    setState(() {
      if (success) {
        _commitHash = commitHash;
        _version = version;
        _phase = DeployPhase.buildReady;
        _statusMessage = '빌드 완료 ✓';

        // 이미 사전 승인된 경우 → preparing 단계로 자동 전환됨
        // (Pylon에서 deploy_start를 바로 보내므로)
        if (_confirmed) {
          _phase = DeployPhase.preparing;
          _statusMessage = '다른 Pylon 준비 중...';
        }
      } else {
        _phase = DeployPhase.error;
        _statusMessage = '빌드 실패';
        _errorMessage = error;
      }
      _progressTimer?.cancel();
    });
  }

  void _handleAckReceived(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final success = payload['success'] as bool? ?? false;
    final totalAcks = payload['totalAcks'] as int? ?? 0;

    setState(() {
      _pylonAckCount = totalAcks;

      // 일단 1개 이상 ack 받으면 ready로 전환 (추후 Pylon 목록 관리 필요)
      if (totalAcks > 0) {
        _phase = DeployPhase.ready;
        _statusMessage = '준비 완료! GO 버튼을 눌러주세요.';
      }
    });
  }

  void _handleDeployRestarting(Map<String, dynamic>? payload) {
    setState(() {
      _phase = DeployPhase.deploying;
      _statusMessage = '배포 중... 잠시 후 재연결됩니다.';
    });
  }

  void _handleDeployError(Map<String, dynamic>? payload) {
    final error = payload?['error'] as String? ?? '알 수 없는 오류';
    setState(() {
      _phase = DeployPhase.error;
      _statusMessage = '배포 실패';
      _errorMessage = error;
      _progressTimer?.cancel();
    });
  }

  /// 배포 시작 (빌드 요청)
  void _startBuild() {
    if (_selectedPylonId == null) {
      setState(() {
        _errorMessage = 'Pylon을 선택해주세요';
      });
      return;
    }

    setState(() {
      _phase = DeployPhase.building;
      _statusMessage = '빌드 시작...';
      _errorMessage = null;
      _confirmed = false;
      _buildTasks = {};
      _startTime = DateTime.now();
      _pylonAckCount = 0;
    });

    // 배포 준비 요청 전송
    ref.read(relayServiceProvider).sendDeployPrepare(_selectedPylonId!);
  }

  /// 확인 버튼 (토글)
  void _toggleConfirm() {
    if (_selectedPylonId == null) return;

    setState(() {
      _confirmed = !_confirmed;
    });

    // Pylon에 전송
    ref.read(relayServiceProvider).sendDeployConfirm(
      _selectedPylonId!,
      preApproved: _confirmed && _phase == DeployPhase.building,
      cancel: !_confirmed,
    );

    // 빌드 완료 상태에서 승인하면 → preparing으로 전환됨 (Pylon에서 deploy_start)
    if (_confirmed && _phase == DeployPhase.buildReady) {
      setState(() {
        _phase = DeployPhase.preparing;
        _statusMessage = '다른 Pylon 준비 중...';
      });
    }
  }

  /// GO 버튼 (배포 실행)
  void _executeDeploy() {
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!).inSeconds;
      _saveBuildTime(elapsed);
    }

    setState(() {
      _phase = DeployPhase.deploying;
      _statusMessage = '배포 실행 중...';
    });

    ref.read(relayServiceProvider).sendDeployGo();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _cancel() {
    _progressTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pylons = ref.watch(pylonListProvider);

    return AlertDialog(
      backgroundColor: NordColors.nord1,
      title: Row(
        children: [
          const Icon(Icons.rocket_launch, color: NordColors.nord13),
          const SizedBox(width: 8),
          const Text('배포', style: TextStyle(color: NordColors.nord5)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pylon 선택 (idle 상태에서만)
            if (_phase == DeployPhase.idle) ...[
              const Text(
                '주도 Pylon 선택:',
                style: TextStyle(color: NordColors.nord4, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...pylons.map((pylon) => RadioListTile<int>(
                title: Text(
                  '${pylon.icon} ${pylon.name}',
                  style: const TextStyle(color: NordColors.nord5),
                ),
                subtitle: Text(
                  'Device ID: ${pylon.deviceId}',
                  style: const TextStyle(color: NordColors.nord4, fontSize: 12),
                ),
                value: pylon.deviceId,
                groupValue: _selectedPylonId,
                activeColor: NordColors.nord10,
                onChanged: (value) {
                  setState(() {
                    _selectedPylonId = value;
                    _errorMessage = null;
                  });
                },
              )),
              const SizedBox(height: 16),
            ],

            // 빌드 태스크 상태 표시
            if (_buildTasks.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NordColors.nord0,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '빌드 상태',
                      style: TextStyle(
                        color: NordColors.nord4,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: _buildTasks.entries.map((e) {
                        final status = e.value;
                        Color color;
                        IconData icon;

                        if (status == 'done') {
                          color = NordColors.nord14;
                          icon = Icons.check_circle;
                        } else if (status == 'error') {
                          color = NordColors.nord11;
                          icon = Icons.error;
                        } else if (status == 'waiting') {
                          color = NordColors.nord4;
                          icon = Icons.schedule;
                        } else {
                          color = NordColors.nord13;
                          icon = Icons.sync;
                        }

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: color, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${e.key.toUpperCase()}',
                              style: TextStyle(color: color, fontSize: 12),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 상태 메시지
            Text(
              _statusMessage,
              style: TextStyle(
                color: _phase == DeployPhase.error
                    ? NordColors.nord11
                    : _phase == DeployPhase.ready
                        ? NordColors.nord14
                        : NordColors.nord4,
                fontSize: 14,
              ),
            ),

            // 버전/커밋 정보
            if (_commitHash != null && _version != null) ...[
              const SizedBox(height: 4),
              Text(
                'v$_version ($_commitHash)',
                style: const TextStyle(color: NordColors.nord4, fontSize: 12),
              ),
            ],

            // Pylon ack 상태
            if (_pylonAckCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '준비된 Pylon: $_pylonAckCount',
                style: const TextStyle(color: NordColors.nord4, fontSize: 12),
              ),
            ],

            // 에러 메시지
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NordColors.nord11.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: NordColors.nord11, fontSize: 12),
                ),
              ),
            ],

            // 사전 승인 안내
            if (_phase == DeployPhase.building && !_confirmed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NordColors.nord10.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '💡 빌드 완료 전에 미리 승인하면 바로 다음 단계로 진행됩니다.',
                  style: TextStyle(color: NordColors.nord4, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // 취소 버튼
        TextButton(
          onPressed: _phase == DeployPhase.deploying ? null : _cancel,
          child: const Text('취소', style: TextStyle(color: NordColors.nord4)),
        ),

        // 확인 버튼 (빌드 중 / 빌드 완료 상태)
        if (_phase == DeployPhase.building || _phase == DeployPhase.buildReady)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _confirmed ? NordColors.nord12 : NordColors.nord10,
            ),
            onPressed: _toggleConfirm,
            child: Text(
              _confirmed ? '승인 취소' : (_phase == DeployPhase.building ? '미리 승인' : '승인'),
              style: const TextStyle(color: Colors.white),
            ),
          ),

        // 배포 시작 버튼 (idle 상태)
        if (_phase == DeployPhase.idle)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NordColors.nord10),
            onPressed: _selectedPylonId != null ? _startBuild : null,
            child: const Text('배포 시작'),
          ),

        // GO 버튼 (ready 상태)
        if (_phase == DeployPhase.ready)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NordColors.nord14),
            onPressed: _executeDeploy,
            child: const Text('GO', style: TextStyle(color: NordColors.nord0, fontWeight: FontWeight.bold)),
          ),

        // 재시도 버튼 (error 상태)
        if (_phase == DeployPhase.error)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NordColors.nord12),
            onPressed: _startBuild,
            child: const Text('재시도'),
          ),

        // 배포 중 로딩
        if (_phase == DeployPhase.deploying || _phase == DeployPhase.preparing)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NordColors.nord3),
            onPressed: null,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(NordColors.nord5),
              ),
            ),
          ),
      ],
    );
  }
}
