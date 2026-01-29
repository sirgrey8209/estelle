import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/claude_usage.dart';
import '../../data/models/deploy_status.dart';
import 'relay_provider.dart';
import 'workspace_provider.dart';

// ============ Claude Usage ============

/// Claude 사용량 상태 (Pylon에서 누적된 값)
final claudeUsageProvider =
    StateNotifierProvider<ClaudeUsageNotifier, ClaudeUsage>((ref) {
  return ClaudeUsageNotifier(ref);
});

class ClaudeUsageNotifier extends StateNotifier<ClaudeUsage> {
  final Ref _ref;
  StreamSubscription? _subscription;

  ClaudeUsageNotifier(this._ref) : super(ClaudeUsage.empty()) {
    _listenToMessages();
  }

  void _listenToMessages() {
    _subscription = _ref.read(relayServiceProvider).messageStream.listen(
      (data) {
        try {
          final type = data['type'] as String?;
          // pylon_status에서 사용량 받기
          if (type == 'pylon_status') {
            final payload = data['payload'] as Map<String, dynamic>?;
            final claudeUsage = payload?['claudeUsage'] as Map<String, dynamic>?;
            if (claudeUsage != null) {
              state = ClaudeUsage.fromPylonStatus(claudeUsage);
            }
          }
        } catch (e, stackTrace) {
          debugPrint('[ClaudeUsage] Exception: $e\n$stackTrace');
        }
      },
      onError: (error, stackTrace) {
        debugPrint('[ClaudeUsage] Stream error: $error\n$stackTrace');
      },
    );
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
        _ref.read(relayServiceProvider).messageStream.listen(
      (data) {
        try {
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
            case 'deploy_log':
              _handleDeployLog(payload);
              break;
          }
        } catch (e, stackTrace) {
          debugPrint('[DeployTracking] Exception: $e\n$stackTrace');
        }
      },
      onError: (error, stackTrace) {
        debugPrint('[DeployTracking] Stream error: $error\n$stackTrace');
      },
    );
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
        final pylons = _ref.read(pylonListWorkspacesProvider);
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

  void _handleDeployLog(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final line = payload['line'] as String?;
    if (line == null) return;

    // 최대 100줄 유지
    final newLogs = [...state.logs, line];
    if (newLogs.length > 100) {
      newLogs.removeAt(0);
    }

    state = state.copyWith(logs: newLogs);
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
      clearLogs: true,
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
      final pylons = _ref.read(pylonListWorkspacesProvider);
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

  /// 로그 박스 토글
  void toggleLogExpanded() {
    state = state.copyWith(logExpanded: !state.logExpanded);
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

// ============ Version Check ============

/// 배포 버전 정보
class DeployVersionInfo {
  final String? version;
  final String? commit;
  final String? buildTime;
  final String? apkUrl;
  final String? exeUrl;
  final String? error;
  final bool isLoading;
  final bool isUpdating;

  const DeployVersionInfo({
    this.version,
    this.commit,
    this.buildTime,
    this.apkUrl,
    this.exeUrl,
    this.error,
    this.isLoading = false,
    this.isUpdating = false,
  });

  DeployVersionInfo copyWith({
    String? version,
    String? commit,
    String? buildTime,
    String? apkUrl,
    String? exeUrl,
    String? error,
    bool? isLoading,
    bool? isUpdating,
    bool clearError = false,
  }) {
    return DeployVersionInfo(
      version: version ?? this.version,
      commit: commit ?? this.commit,
      buildTime: buildTime ?? this.buildTime,
      apkUrl: apkUrl ?? this.apkUrl,
      exeUrl: exeUrl ?? this.exeUrl,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
    );
  }

  static const DeployVersionInfo initial = DeployVersionInfo();
}

/// 배포 버전 정보 Provider
final deployVersionProvider =
    StateNotifierProvider<DeployVersionNotifier, DeployVersionInfo>((ref) {
  return DeployVersionNotifier(ref);
});

class DeployVersionNotifier extends StateNotifier<DeployVersionInfo> {
  final Ref _ref;
  StreamSubscription? _subscription;

  DeployVersionNotifier(this._ref) : super(DeployVersionInfo.initial) {
    _listenToMessages();
  }

  void _listenToMessages() {
    _subscription =
        _ref.read(relayServiceProvider).messageStream.listen(
      (data) {
        try {
          final type = data['type'] as String?;
          final payload = data['payload'] as Map<String, dynamic>?;

          if (type == 'version_check_result') {
            _handleVersionCheckResult(payload);
          } else if (type == 'app_update_result') {
            _handleAppUpdateResult(payload);
          }
        } catch (e, stackTrace) {
          debugPrint('[DeployVersion] Exception: $e\n$stackTrace');
        }
      },
      onError: (error, stackTrace) {
        debugPrint('[DeployVersion] Stream error: $error\n$stackTrace');
      },
    );
  }

  void _handleVersionCheckResult(Map<String, dynamic>? payload) {
    if (payload == null) return;

    state = state.copyWith(
      version: payload['version'] as String?,
      commit: payload['commit'] as String?,
      buildTime: payload['buildTime'] as String?,
      apkUrl: payload['apkUrl'] as String?,
      exeUrl: payload['exeUrl'] as String?,
      error: payload['error'] as String?,
      isLoading: false,
    );
  }

  void _handleAppUpdateResult(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final success = payload['success'] as bool? ?? false;
    if (success) {
      // 업데이트 URL 받음 - 다운로드 시작
      state = state.copyWith(
        apkUrl: payload['apkUrl'] as String?,
        exeUrl: payload['exeUrl'] as String?,
        isUpdating: false,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        error: payload['error'] as String?,
        isUpdating: false,
      );
    }
  }

  /// 버전 체크 요청
  void requestVersionCheck() {
    state = state.copyWith(isLoading: true, clearError: true);
    _ref.read(relayServiceProvider).requestVersionCheck();
  }

  /// 앱 업데이트 요청
  void requestUpdate(int pylonDeviceId) {
    state = state.copyWith(isUpdating: true, clearError: true);
    _ref.read(relayServiceProvider).requestAppUpdate(pylonDeviceId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
