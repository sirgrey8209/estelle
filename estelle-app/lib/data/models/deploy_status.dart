/// 배포 단계
enum DeployPhase {
  idle,       // 초기: Pylon 선택
  building,   // P1 빌드 중 (사전 승인 가능)
  buildReady, // P1 빌드 완료, 승인 대기
  preparing,  // 다른 Pylon 준비 중
  ready,      // 모든 준비 완료, GO 대기
  deploying,  // 배포 실행 중
  error,      // 오류
}

/// 배포 상태 데이터 모델
class DeployStatus {
  final DeployPhase phase;
  final String statusMessage;
  final String? errorMessage;
  final int? selectedPylonId;
  final bool confirmed;
  final Map<String, String> buildTasks;
  final String? commitHash;
  final String? version;
  final int pylonAckCount;

  const DeployStatus({
    this.phase = DeployPhase.idle,
    this.statusMessage = '배포할 Pylon을 선택하세요',
    this.errorMessage,
    this.selectedPylonId,
    this.confirmed = false,
    this.buildTasks = const {},
    this.commitHash,
    this.version,
    this.pylonAckCount = 0,
  });

  DeployStatus copyWith({
    DeployPhase? phase,
    String? statusMessage,
    String? errorMessage,
    int? selectedPylonId,
    bool? confirmed,
    Map<String, String>? buildTasks,
    String? commitHash,
    String? version,
    int? pylonAckCount,
    bool clearError = false,
  }) {
    return DeployStatus(
      phase: phase ?? this.phase,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedPylonId: selectedPylonId ?? this.selectedPylonId,
      confirmed: confirmed ?? this.confirmed,
      buildTasks: buildTasks ?? this.buildTasks,
      commitHash: commitHash ?? this.commitHash,
      version: version ?? this.version,
      pylonAckCount: pylonAckCount ?? this.pylonAckCount,
    );
  }

  static const DeployStatus initial = DeployStatus();
}
