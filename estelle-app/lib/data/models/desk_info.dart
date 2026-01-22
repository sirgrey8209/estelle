/// Desk information model
class DeskInfo {
  final int deviceId;
  final String deviceName;
  final String deviceIcon;
  final String deskId;
  final String deskName;
  final String workingDir;
  final String status; // idle, working, permission, offline
  final bool isActive;
  final bool canResume;
  final bool hasActiveSession;

  const DeskInfo({
    required this.deviceId,
    required this.deviceName,
    required this.deviceIcon,
    required this.deskId,
    required this.deskName,
    this.workingDir = '',
    this.status = 'idle',
    this.isActive = false,
    this.canResume = false,
    this.hasActiveSession = false,
  });

  /// Empty desk (for null checks)
  factory DeskInfo.empty() => const DeskInfo(
    deviceId: 0,
    deviceName: '',
    deviceIcon: '',
    deskId: '',
    deskName: '',
  );

  String get fullName => '$deviceName/$deskName';

  bool get isWorking => status == 'working';
  bool get needsPermission => status == 'permission';
  bool get isIdle => status == 'idle';
  bool get isOffline => status == 'offline';

  DeskInfo copyWith({
    int? deviceId,
    String? deviceName,
    String? deviceIcon,
    String? deskId,
    String? deskName,
    String? workingDir,
    String? status,
    bool? isActive,
    bool? canResume,
    bool? hasActiveSession,
  }) {
    return DeskInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceIcon: deviceIcon ?? this.deviceIcon,
      deskId: deskId ?? this.deskId,
      deskName: deskName ?? this.deskName,
      workingDir: workingDir ?? this.workingDir,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      canResume: canResume ?? this.canResume,
      hasActiveSession: hasActiveSession ?? this.hasActiveSession,
    );
  }

  factory DeskInfo.fromJson(Map<String, dynamic> json) {
    return DeskInfo(
      deviceId: json['deviceId'] as int? ?? 0,
      deviceName: json['deviceName'] as String? ?? '',
      deviceIcon: json['deviceIcon'] as String? ?? '💻',
      deskId: json['deskId'] as String? ?? '',
      deskName: json['deskName'] as String? ?? '',
      workingDir: json['workingDir'] as String? ?? '',
      status: json['status'] as String? ?? 'idle',
      isActive: json['isActive'] as bool? ?? false,
      canResume: json['canResume'] as bool? ?? false,
      hasActiveSession: json['hasActiveSession'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'deviceIcon': deviceIcon,
    'deskId': deskId,
    'deskName': deskName,
    'workingDir': workingDir,
    'status': status,
    'isActive': isActive,
    'canResume': canResume,
    'hasActiveSession': hasActiveSession,
  };
}

/// Pylon information model
class PylonInfo {
  final int deviceId;
  final String name;
  final String icon;
  final List<DeskInfo> desks;

  const PylonInfo({
    required this.deviceId,
    required this.name,
    required this.icon,
    this.desks = const [],
  });

  PylonInfo copyWith({
    int? deviceId,
    String? name,
    String? icon,
    List<DeskInfo>? desks,
  }) {
    return PylonInfo(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      desks: desks ?? this.desks,
    );
  }

  factory PylonInfo.fromJson(Map<String, dynamic> json) {
    return PylonInfo(
      deviceId: json['deviceId'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '💻',
      desks: (json['desks'] as List<dynamic>?)
          ?.map((e) => DeskInfo.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'name': name,
    'icon': icon,
    'desks': desks.map((e) => e.toJson()).toList(),
  };
}
