import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/claude_usage.dart';
import '../../data/models/deploy_status.dart';
import 'relay_provider.dart';
import 'desk_provider.dart';

// ============ Claude Usage ============

/// Claude 사용량 상태
final claudeUsageProvider =
    StateNotifierProvider<ClaudeUsageNotifier, AsyncValue<ClaudeUsage>>((ref) {
  return ClaudeUsageNotifier(ref);
});

class ClaudeUsageNotifier extends StateNotifier<AsyncValue<ClaudeUsage>> {
  final Ref _ref;
  StreamSubscription? _subscription;

  ClaudeUsageNotifier(this._ref) : super(const AsyncValue.loading()) {
    _listenToMessages();
  }

  void _listenToMessages() {
    _subscription = _ref.read(relayServiceProvider).messageStream.listen((data) {
      final type = data['type'] as String?;
      if (type == 'claude_usage_result') {
        final payload = data['payload'] as Map<String, dynamic>?;
        if (payload != null) {
          state = AsyncValue.data(ClaudeUsage.fromJson(payload));
        }
      }
    });
  }

  /// Claude 사용량 요청
  void requestUsage() {
    state = const AsyncValue.loading();
    _ref.read(relayServiceProvider).requestClaudeUsage();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// ============ Deploy Tracking ============

/// 배포 상태 추적
final deployStatusProvider =
    StateNotifierProvider<DeployTrackingNotifier, DeployStatus>((ref) {
  return DeployTrackingNotifier(ref);
});

class DeployTrackingNotifier extends StateNotifier<DeployStatus> {
  final Ref _ref;
  StreamSubscription? _subscription;
  DateTime? _startTime;

  DeployTrackingNotifier(this._ref) : super(DeployStatus.initial) {
    _listenToMessages();
  }

  Future<void> _saveBuildTime(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final times = prefs.getStringList('deploy_times') ?? [];
    times.insert(0, seconds.toString());
    if (times.length > 5) times.removeLast();
    await prefs.setStringList('deploy_times', times);
  }

  void _listenToMessages() {
    _subscription =
        _ref.read(relayServiceProvider).messageStream.listen((data) {
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

    state = state.copyWith(
      buildTasks:
          tasks?.map((k, v) => MapEntry(k, v.toString())) ?? state.buildTasks,
      statusMessage: message ?? state.statusMessage,
    );
  }

  void _handleDeployReady(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final success = payload['success'] as bool? ?? false;
    final error = payload['error'] as String?;
    final commitHash = payload['commitHash'] as String?;
    final version = payload['version'] as String?;

    if (success) {
      // 이미 사전 승인된 경우 → 다른 Pylon 체크
      if (state.confirmed) {
        final pylons = _ref.read(pylonListProvider);
        if (pylons.length <= 1) {
          // Pylon이 1대뿐이면 바로 ready
          state = state.copyWith(
            phase: DeployPhase.ready,
            statusMessage: '준비 완료! GO 버튼을 눌러주세요.',
            commitHash: commitHash,
            version: version,
          );
        } else {
          state = state.copyWith(
            phase: DeployPhase.preparing,
            statusMessage: '다른 Pylon 준비 중...',
            commitHash: commitHash,
            version: version,
          );
        }
      } else {
        state = state.copyWith(
          phase: DeployPhase.buildReady,
          statusMessage: '빌드 완료 ✓',
          commitHash: commitHash,
          version: version,
        );
      }
    } else {
      state = state.copyWith(
        phase: DeployPhase.error,
        statusMessage: '빌드 실패',
        errorMessage: error,
      );
    }
  }

  void _handleAckReceived(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final totalAcks = payload['totalAcks'] as int? ?? 0;

    // 1개 이상 ack 받으면 ready로 전환
    if (totalAcks > 0) {
      state = state.copyWith(
        phase: DeployPhase.ready,
        statusMessage: '준비 완료! GO 버튼을 눌러주세요.',
        pylonAckCount: totalAcks,
      );
    } else {
      state = state.copyWith(pylonAckCount: totalAcks);
    }
  }

  void _handleDeployRestarting(Map<String, dynamic>? payload) {
    state = state.copyWith(
      phase: DeployPhase.deploying,
      statusMessage: '배포 중... 잠시 후 재연결됩니다.',
    );
  }

  void _handleDeployError(Map<String, dynamic>? payload) {
    final error = payload?['error'] as String? ?? '알 수 없는 오류';
    state = state.copyWith(
      phase: DeployPhase.error,
      statusMessage: '배포 실패',
      errorMessage: error,
    );
  }

  /// Pylon 선택
  void selectPylon(int pylonId) {
    state = state.copyWith(
      selectedPylonId: pylonId,
      clearError: true,
    );
  }

  /// 배포 시작 (빌드 요청)
  void startBuild() {
    if (state.selectedPylonId == null) {
      state = state.copyWith(errorMessage: 'Pylon을 선택해주세요');
      return;
    }

    _startTime = DateTime.now();
    state = state.copyWith(
      phase: DeployPhase.building,
      statusMessage: '빌드 시작...',
      confirmed: false,
      buildTasks: {},
      pylonAckCount: 0,
      clearError: true,
    );

    _ref.read(relayServiceProvider).sendDeployPrepare(state.selectedPylonId!);
  }

  /// 확인 버튼 (토글)
  void toggleConfirm() {
    if (state.selectedPylonId == null) return;

    final newConfirmed = !state.confirmed;
    state = state.copyWith(confirmed: newConfirmed);

    _ref.read(relayServiceProvider).sendDeployConfirm(
          state.selectedPylonId!,
          preApproved: newConfirmed && state.phase == DeployPhase.building,
          cancel: !newConfirmed,
        );

    // 빌드 완료 상태에서 승인하면 → 다른 Pylon 체크
    if (newConfirmed && state.phase == DeployPhase.buildReady) {
      final pylons = _ref.read(pylonListProvider);
      if (pylons.length <= 1) {
        state = state.copyWith(
          phase: DeployPhase.ready,
          statusMessage: '준비 완료! GO 버튼을 눌러주세요.',
        );
      } else {
        state = state.copyWith(
          phase: DeployPhase.preparing,
          statusMessage: '다른 Pylon 준비 중...',
        );
      }
    }
  }

  /// GO 버튼 (배포 실행)
  void executeDeploy() {
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!).inSeconds;
      _saveBuildTime(elapsed);
    }

    state = state.copyWith(
      phase: DeployPhase.deploying,
      statusMessage: '배포 실행 중...',
    );

    _ref.read(relayServiceProvider).sendDeployGo();
  }

  /// 상태 초기화
  void reset() {
    state = DeployStatus.initial;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
