/// JSON에서 List를 안전하게 추출
List<dynamic>? _safeList(dynamic value) {
  if (value == null) return null;
  if (value is List) return value;
  return null;
}

/// 대화 상태 enum
///
/// 우선순위 (높은 것이 우선):
/// 1. error - 에러 발생
/// 2. waiting - 권한 요청 대기 중
/// 3. working - 작업 중
/// 4. unread - 읽지 않은 메시지 있음
/// 5. idle - 기본 상태
/// 6. finishing - 작업완료 진행 중
/// 7. finished - 작업완료 완료 (다이얼로그 대기)
enum ConversationStatus {
  idle,
  unread,
  working,
  waiting,
  finishing,
  finished,
  error;

  /// JSON 문자열에서 변환
  static ConversationStatus fromString(String? value) {
    switch (value) {
      case 'error':
        return ConversationStatus.error;
      case 'waiting':
        return ConversationStatus.waiting;
      case 'working':
        return ConversationStatus.working;
      case 'finishing':
        return ConversationStatus.finishing;
      case 'finished':
        return ConversationStatus.finished;
      case 'unread':
        return ConversationStatus.unread;
      default:
        return ConversationStatus.idle;
    }
  }

  /// StatusDot용 문자열 반환
  String get dotStatus {
    switch (this) {
      case ConversationStatus.error:
        return 'error';
      case ConversationStatus.waiting:
        return 'waiting';
      case ConversationStatus.working:
        return 'working';
      case ConversationStatus.finishing:
        return 'working'; // finishing도 작업 중으로 표시
      case ConversationStatus.finished:
        return 'waiting'; // finished는 대기 상태로 표시
      case ConversationStatus.unread:
        return 'unread';
      case ConversationStatus.idle:
        return 'idle';
    }
  }

  /// 우선순위 (높을수록 우선)
  int get priority {
    switch (this) {
      case ConversationStatus.error:
        return 5;
      case ConversationStatus.finished:
        return 4; // finished는 다이얼로그 대기 상태로 높은 우선순위
      case ConversationStatus.waiting:
        return 3;
      case ConversationStatus.finishing:
        return 2; // finishing은 working과 동일
      case ConversationStatus.working:
        return 2;
      case ConversationStatus.unread:
        return 1;
      case ConversationStatus.idle:
        return 0;
    }
  }

  /// 두 상태 중 우선순위가 높은 것 반환
  static ConversationStatus higher(ConversationStatus a, ConversationStatus b) {
    return a.priority >= b.priority ? a : b;
  }
}

/// 워크스페이스 정보 모델
class WorkspaceInfo {
  final int deviceId; // Pylon의 기기 ID
  final String deviceName; // Pylon 이름
  final String deviceIcon; // Pylon 아이콘
  final String workspaceId;
  final String name;
  final String workingDir;
  final List<ConversationInfo> conversations;
  final List<TaskInfo> tasks;
  final WorkerStatus? workerStatus;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastUsed;

  WorkspaceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.deviceIcon,
    required this.workspaceId,
    required this.name,
    required this.workingDir,
    required this.conversations,
    required this.tasks,
    this.workerStatus,
    this.isActive = false,
    this.createdAt,
    this.lastUsed,
  });

  factory WorkspaceInfo.fromJson(Map<String, dynamic> json, {
    required int deviceId,
    required String deviceName,
    required String deviceIcon,
  }) {
    return WorkspaceInfo(
      deviceId: deviceId,
      deviceName: deviceName,
      deviceIcon: deviceIcon,
      workspaceId: json['workspaceId'] ?? '',
      name: json['name'] ?? '',
      workingDir: json['workingDir'] ?? '',
      conversations: (_safeList(json['conversations']))
              ?.map((c) => ConversationInfo.fromJson(c))
              .toList() ??
          [],
      tasks: (_safeList(json['tasks']))
              ?.map((t) => TaskInfo.fromJson(t))
              .toList() ??
          [],
      workerStatus: json['workerStatus'] != null
          ? WorkerStatus.fromJson(json['workerStatus'])
          : null,
      isActive: json['isActive'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      lastUsed: json['lastUsed'] != null
          ? DateTime.tryParse(json['lastUsed'].toString())
          : null,
    );
  }

  /// 워크스페이스 내 최고 우선순위 상태 (접힌 상태에서 표시용)
  /// 우선순위: error > waiting > working > unread > idle
  String get priorityStatus {
    // 1. 에러/실패 체크
    for (final task in tasks) {
      if (task.status == 'failed') return 'error';
    }
    for (final conv in conversations) {
      if (conv.status == ConversationStatus.error) return 'error';
    }

    // 2. 대기 중 체크 (권한 요청 등)
    for (final conv in conversations) {
      if (conv.status == ConversationStatus.waiting) return 'waiting';
    }

    // 3. 작업 중 체크
    if (workerStatus?.status == 'running') return 'working';
    for (final conv in conversations) {
      if (conv.status == ConversationStatus.working) return 'working';
    }

    // 4. 읽지 않음 체크
    for (final conv in conversations) {
      if (conv.status == ConversationStatus.unread) return 'unread';
    }

    // 5. idle
    return 'idle';
  }

  WorkspaceInfo copyWith({
    int? deviceId,
    String? deviceName,
    String? deviceIcon,
    String? workspaceId,
    String? name,
    String? workingDir,
    List<ConversationInfo>? conversations,
    List<TaskInfo>? tasks,
    WorkerStatus? workerStatus,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return WorkspaceInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceIcon: deviceIcon ?? this.deviceIcon,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      workingDir: workingDir ?? this.workingDir,
      conversations: conversations ?? this.conversations,
      tasks: tasks ?? this.tasks,
      workerStatus: workerStatus ?? this.workerStatus,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
}

/// 대화 정보 모델
class ConversationInfo {
  final String conversationId;
  final String name;
  final String skillType; // general, planner, worker
  final String? claudeSessionId;
  final ConversationStatus status;
  final String permissionMode; // default, acceptEdits, bypassPermissions
  final DateTime? createdAt;

  ConversationInfo({
    required this.conversationId,
    required this.name,
    this.skillType = 'general',
    this.claudeSessionId,
    this.status = ConversationStatus.idle,
    this.permissionMode = 'default',
    this.createdAt,
  });

  factory ConversationInfo.fromJson(Map<String, dynamic> json) {
    // status와 unread를 결합하여 ConversationStatus 결정
    final statusStr = json['status'] as String? ?? 'idle';
    final unread = json['unread'] as bool? ?? false;

    ConversationStatus status;
    if (statusStr == 'error') {
      status = ConversationStatus.error;
    } else if (statusStr == 'waiting') {
      status = ConversationStatus.waiting;
    } else if (statusStr == 'working') {
      status = ConversationStatus.working;
    } else if (unread) {
      status = ConversationStatus.unread;
    } else {
      status = ConversationStatus.idle;
    }

    return ConversationInfo(
      conversationId: json['conversationId'] ?? '',
      name: json['name'] ?? '',
      skillType: json['skillType'] ?? 'general',
      claudeSessionId: json['claudeSessionId'],
      status: status,
      permissionMode: json['permissionMode'] ?? 'default',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  bool get isWorking => status == ConversationStatus.working;
  bool get isWaiting => status == ConversationStatus.waiting;
  bool get hasError => status == ConversationStatus.error;
  bool get unread => status == ConversationStatus.unread;
  bool get canResume => claudeSessionId != null;

  /// StatusDot용 상태 문자열
  String get dotStatus => status.dotStatus;

  /// 스킬 타입에 해당하는 아이콘
  String get skillIcon {
    switch (skillType) {
      case 'planner':
        return '📋';
      case 'worker':
        return '🔧';
      default:
        return '💬';
    }
  }

  ConversationInfo copyWith({
    String? conversationId,
    String? name,
    String? skillType,
    String? claudeSessionId,
    ConversationStatus? status,
    String? permissionMode,
    DateTime? createdAt,
  }) {
    return ConversationInfo(
      conversationId: conversationId ?? this.conversationId,
      name: name ?? this.name,
      skillType: skillType ?? this.skillType,
      claudeSessionId: claudeSessionId ?? this.claudeSessionId,
      status: status ?? this.status,
      permissionMode: permissionMode ?? this.permissionMode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 태스크 정보 모델
class TaskInfo {
  final String id;
  final String title;
  final String status; // pending, running, done, failed
  final String? fileName;
  final String? content; // 상세 조회 시에만 포함
  final bool? truncated;
  final String? error;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  TaskInfo({
    required this.id,
    required this.title,
    this.status = 'pending',
    this.fileName,
    this.content,
    this.truncated,
    this.error,
    this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  factory TaskInfo.fromJson(Map<String, dynamic> json) {
    return TaskInfo(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      status: json['status'] ?? 'pending',
      fileName: json['fileName'],
      content: json['content'],
      truncated: json['truncated'],
      error: json['error'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isRunning => status == 'running';
  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';

  TaskInfo copyWith({
    String? id,
    String? title,
    String? status,
    String? fileName,
    String? content,
    bool? truncated,
    String? error,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return TaskInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      content: content ?? this.content,
      truncated: truncated ?? this.truncated,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// 워커 상태 모델
class WorkerStatus {
  final String workspaceId;
  final String status; // idle, running
  final TaskInfo? currentTask;
  final WorkerQueue queue;

  WorkerStatus({
    required this.workspaceId,
    required this.status,
    this.currentTask,
    required this.queue,
  });

  factory WorkerStatus.fromJson(Map<String, dynamic> json) {
    return WorkerStatus(
      workspaceId: json['workspaceId'] ?? '',
      status: json['status'] ?? 'idle',
      currentTask: json['currentTask'] != null
          ? TaskInfo.fromJson(json['currentTask'])
          : null,
      queue: WorkerQueue.fromJson(json['queue'] ?? {}),
    );
  }

  bool get isRunning => status == 'running';
  bool get isIdle => status == 'idle';
}

/// 워커 큐 상태
class WorkerQueue {
  final int pending;
  final int total;

  WorkerQueue({
    required this.pending,
    required this.total,
  });

  factory WorkerQueue.fromJson(Map<String, dynamic> json) {
    return WorkerQueue(
      pending: json['pending'] ?? 0,
      total: json['total'] ?? 0,
    );
  }
}

/// Pylon별 워크스페이스 그룹
class PylonWorkspaces {
  final int deviceId;
  final String name;
  final String icon;
  final List<WorkspaceInfo> workspaces;

  PylonWorkspaces({
    required this.deviceId,
    required this.name,
    required this.icon,
    required this.workspaces,
  });
}
