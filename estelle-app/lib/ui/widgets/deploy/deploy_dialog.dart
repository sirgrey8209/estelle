import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/desk_info.dart';
import '../../../state/providers/relay_provider.dart';
import '../../../state/providers/desk_provider.dart';

/// 배포 상태
enum DeployStatus {
  idle,       // 대기
  preparing,  // 준비 중 (git pull, fly deploy, apk build)
  ready,      // 준비 완료, 실행 대기
  deploying,  // 배포 실행 중
  completed,  // 완료
  error,      // 오류
}

/// 배포 다이얼로그
class DeployDialog extends ConsumerStatefulWidget {
  const DeployDialog({super.key});

  @override
  ConsumerState<DeployDialog> createState() => _DeployDialogState();
}

class _DeployDialogState extends ConsumerState<DeployDialog> {
  DeployStatus _status = DeployStatus.idle;
  String _statusMessage = '배포할 Pylon을 선택하세요';
  String? _errorMessage;

  int? _selectedPylonId;
  final Map<int, bool> _pylonReadyStatus = {}; // deviceId -> ready

  DateTime? _startTime;
  Timer? _progressTimer;
  double _progress = 0.0;
  int _estimatedSeconds = 180; // 기본 3분

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

  /// 최근 빌드 시간 통계 로드
  Future<void> _loadBuildTimeStats() async {
    final prefs = await SharedPreferences.getInstance();
    final times = prefs.getStringList('deploy_times') ?? [];

    if (times.isNotEmpty) {
      final recentTimes = times.take(3).map((t) => int.tryParse(t) ?? 180).toList();
      _estimatedSeconds = (recentTimes.reduce((a, b) => a + b) / recentTimes.length).round();
    }
  }

  /// 빌드 시간 저장
  Future<void> _saveBuildTime(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final times = prefs.getStringList('deploy_times') ?? [];
    times.insert(0, seconds.toString());
    if (times.length > 5) times.removeLast(); // 최근 5개만 유지
    await prefs.setStringList('deploy_times', times);
  }

  /// Relay 메시지 리스닝
  void _listenToMessages() {
    _messageSubscription = ref.read(relayServiceProvider).messageStream.listen((data) {
      final type = data['type'] as String?;
      final payload = data['payload'] as Map<String, dynamic>?;

      switch (type) {
        case 'deploy_ready':
          _handleDeployReady(payload);
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

  void _handleDeployReady(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final deviceId = payload['deviceId'] as int?;
    final success = payload['success'] as bool? ?? false;
    final error = payload['error'] as String?;

    if (deviceId != null) {
      setState(() {
        _pylonReadyStatus[deviceId] = success;

        if (!success && error != null) {
          _errorMessage = 'Pylon $deviceId 오류: $error';
        }

        // 선택된 Pylon이 준비되면 상태 변경
        if (deviceId == _selectedPylonId && success) {
          _status = DeployStatus.ready;
          _statusMessage = '준비 완료! 배포 버튼을 눌러주세요.';
          _progressTimer?.cancel();
          _progress = 1.0;
        }
      });
    }
  }

  void _handleDeployRestarting(Map<String, dynamic>? payload) {
    setState(() {
      _status = DeployStatus.deploying;
      _statusMessage = '배포 중... 잠시 후 재연결됩니다.';
    });
  }

  void _handleDeployError(Map<String, dynamic>? payload) {
    final error = payload?['error'] as String? ?? '알 수 없는 오류';
    setState(() {
      _status = DeployStatus.error;
      _statusMessage = '배포 실패';
      _errorMessage = error;
      _progressTimer?.cancel();
    });
  }

  /// 배포 준비 시작
  void _startPrepare() {
    if (_selectedPylonId == null) {
      setState(() {
        _errorMessage = 'Pylon을 선택해주세요';
      });
      return;
    }

    setState(() {
      _status = DeployStatus.preparing;
      _statusMessage = 'git pull, fly deploy, APK 빌드 중...';
      _errorMessage = null;
      _startTime = DateTime.now();
      _progress = 0.0;
      _pylonReadyStatus.clear();
    });

    // 프로그레스 타이머 시작
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_status != DeployStatus.preparing) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_startTime!).inMilliseconds;
      setState(() {
        // 예상 시간의 95%까지만 자동 진행 (나머지는 실제 완료 시)
        _progress = (elapsed / (_estimatedSeconds * 1000)).clamp(0.0, 0.95);
      });
    });

    // 배포 준비 요청 전송
    ref.read(relayServiceProvider).sendDeployPrepare(_selectedPylonId!);
  }

  /// 배포 실행
  void _executeDeploy() {
    // 빌드 시간 저장
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!).inSeconds;
      _saveBuildTime(elapsed);
    }

    setState(() {
      _status = DeployStatus.deploying;
      _statusMessage = '배포 실행 중...';
    });

    // 배포 실행 요청
    ref.read(relayServiceProvider).sendDeployGo();

    // 3초 후 다이얼로그 닫기 (앱도 재시작될 예정)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  /// 취소
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
            // Pylon 선택
            if (_status == DeployStatus.idle) ...[
              const Text(
                'Relay 배포를 담당할 Pylon 선택:',
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

            // 상태 메시지
            Text(
              _statusMessage,
              style: TextStyle(
                color: _status == DeployStatus.error
                    ? NordColors.nord11
                    : NordColors.nord4,
                fontSize: 14,
              ),
            ),

            // 에러 메시지
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NordColors.nord11.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: NordColors.nord11, fontSize: 12),
                ),
              ),
            ],

            // 프로그레스 바
            if (_status == DeployStatus.preparing || _status == DeployStatus.ready) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: NordColors.nord3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _status == DeployStatus.ready ? NordColors.nord14 : NordColors.nord10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _status == DeployStatus.ready
                    ? '준비 완료'
                    : '예상 시간: ${_estimatedSeconds}초 (${(_progress * 100).toInt()}%)',
                style: const TextStyle(color: NordColors.nord4, fontSize: 12),
              ),
            ],

            // Pylon 준비 상태
            if (_pylonReadyStatus.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Pylon 상태:',
                style: TextStyle(color: NordColors.nord4, fontSize: 12),
              ),
              const SizedBox(height: 4),
              ..._pylonReadyStatus.entries.map((entry) => Row(
                children: [
                  Icon(
                    entry.value ? Icons.check_circle : Icons.error,
                    color: entry.value ? NordColors.nord14 : NordColors.nord11,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pylon ${entry.key}',
                    style: const TextStyle(color: NordColors.nord5, fontSize: 12),
                  ),
                ],
              )),
            ],
          ],
        ),
      ),
      actions: [
        // 취소 버튼
        TextButton(
          onPressed: _status == DeployStatus.deploying ? null : _cancel,
          child: const Text('취소', style: TextStyle(color: NordColors.nord4)),
        ),

        // 배포 준비 / 배포 실행 버튼
        if (_status == DeployStatus.idle)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NordColors.nord10),
            onPressed: _selectedPylonId != null ? _startPrepare : null,
            child: const Text('배포 준비'),
          ),

        if (_status == DeployStatus.preparing)
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

        if (_status == DeployStatus.ready)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NordColors.nord14),
            onPressed: _executeDeploy,
            child: const Text('배포 실행', style: TextStyle(color: NordColors.nord0)),
          ),

        if (_status == DeployStatus.error)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NordColors.nord12),
            onPressed: _startPrepare,
            child: const Text('재시도'),
          ),
      ],
    );
  }
}
