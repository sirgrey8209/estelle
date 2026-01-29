/// Base class for Claude messages
sealed class ClaudeMessage {
  String get id;
  int get timestamp;
}

/// 첨부 이미지 정보
class AttachmentInfo {
  final String id;
  final String filename;
  final String? localPath;
  final String? remotePath;

  const AttachmentInfo({
    required this.id,
    required this.filename,
    this.localPath,
    this.remotePath,
  });
}

/// User text message
class UserTextMessage implements ClaudeMessage {
  @override
  final String id;
  final String content;
  final List<AttachmentInfo>? attachments;
  @override
  final int timestamp;

  const UserTextMessage({
    required this.id,
    required this.content,
    this.attachments,
    required this.timestamp,
  });

  /// 메시지 내용에서 이미지 경로 추출
  /// 히스토리에는 [image:파일명] 형식으로 저장됨
  static ({String text, List<AttachmentInfo> attachments}) parseContent(String rawContent) {
    final attachments = <AttachmentInfo>[];
    var text = rawContent;

    // [image:파일명] 또는 [image:/전체/경로] 패턴 파싱
    final imageRegex = RegExp(r'\[image:([^\]]+)\]');
    final matches = imageRegex.allMatches(rawContent);

    int index = 0;
    for (final match in matches) {
      final imagePath = match.group(1)!;
      // 파일명만 추출 (경로 구분자가 있으면 마지막 부분)
      final filename = imagePath.split('/').last.split('\\').last;

      // 전체 경로인지 파일명만인지 확인
      final isFullPath = imagePath.contains('/') || imagePath.contains('\\');

      attachments.add(AttachmentInfo(
        id: 'img_${DateTime.now().millisecondsSinceEpoch}_$index',
        filename: filename,
        // 전체 경로면 localPath로, 파일명만이면 null (나중에 검색)
        localPath: isFullPath ? imagePath : null,
        remotePath: imagePath,
      ));
      text = text.replaceFirst(match.group(0)!, '');
      index++;
    }

    return (text: text.trim(), attachments: attachments);
  }

  UserTextMessage copyWith({
    String? id,
    String? content,
    List<AttachmentInfo>? attachments,
    int? timestamp,
  }) {
    return UserTextMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Assistant text message
class AssistantTextMessage implements ClaudeMessage {
  @override
  final String id;
  final String content;
  @override
  final int timestamp;

  const AssistantTextMessage({
    required this.id,
    required this.content,
    required this.timestamp,
  });

  AssistantTextMessage copyWith({
    String? id,
    String? content,
    int? timestamp,
  }) {
    return AssistantTextMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Tool call message (start or complete)
class ToolCallMessage implements ClaudeMessage {
  @override
  final String id;
  final String toolName;
  final Map<String, dynamic> toolInput;
  final bool isComplete;
  final bool? success;
  final String? output;
  final String? error;
  @override
  final int timestamp;

  const ToolCallMessage({
    required this.id,
    required this.toolName,
    required this.toolInput,
    this.isComplete = false,
    this.success,
    this.output,
    this.error,
    required this.timestamp,
  });

  ToolCallMessage copyWith({
    String? id,
    String? toolName,
    Map<String, dynamic>? toolInput,
    bool? isComplete,
    bool? success,
    String? output,
    String? error,
    int? timestamp,
  }) {
    return ToolCallMessage(
      id: id ?? this.id,
      toolName: toolName ?? this.toolName,
      toolInput: toolInput ?? this.toolInput,
      isComplete: isComplete ?? this.isComplete,
      success: success ?? this.success,
      output: output ?? this.output,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Result info message (tokens, duration)
class ResultInfoMessage implements ClaudeMessage {
  @override
  final String id;
  final int durationMs;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  @override
  final int timestamp;

  const ResultInfoMessage({
    required this.id,
    required this.durationMs,
    required this.inputTokens,
    required this.outputTokens,
    this.cacheReadTokens = 0,
    required this.timestamp,
  });

  ResultInfoMessage copyWith({
    String? id,
    int? durationMs,
    int? inputTokens,
    int? outputTokens,
    int? cacheReadTokens,
    int? timestamp,
  }) {
    return ResultInfoMessage(
      id: id ?? this.id,
      durationMs: durationMs ?? this.durationMs,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      cacheReadTokens: cacheReadTokens ?? this.cacheReadTokens,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Error message
class ErrorMessage implements ClaudeMessage {
  @override
  final String id;
  final String error;
  @override
  final int timestamp;

  const ErrorMessage({
    required this.id,
    required this.error,
    required this.timestamp,
  });

  ErrorMessage copyWith({
    String? id,
    String? error,
    int? timestamp,
  }) {
    return ErrorMessage(
      id: id ?? this.id,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Claude 프로세스 중단 메시지 (빨간 구분선으로 표시)
/// - 사용자가 Stop 버튼을 눌렀을 때
/// - Pylon 재시작으로 세션이 끊겼을 때
class ClaudeAbortedMessage implements ClaudeMessage {
  @override
  final String id;
  final String reason; // user, session_ended
  @override
  final int timestamp;

  const ClaudeAbortedMessage({
    required this.id,
    required this.reason,
    required this.timestamp,
  });

  String get displayText {
    switch (reason) {
      case 'user':
        return '실행 중지됨';
      case 'session_ended':
        return '세션 종료됨';
      default:
        return '중단됨';
    }
  }

  ClaudeAbortedMessage copyWith({
    String? id,
    String? reason,
    int? timestamp,
  }) {
    return ClaudeAbortedMessage(
      id: id ?? this.id,
      reason: reason ?? this.reason,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// 파일 첨부 정보 (Claude → 사용자)
class FileAttachmentInfo {
  final String path;      // Pylon에서의 파일 경로
  final String filename;  // 파일명.확장자
  final String mimeType;
  final String fileType;  // 'image' | 'markdown' | 'text'
  final int size;
  final String? description;

  const FileAttachmentInfo({
    required this.path,
    required this.filename,
    required this.mimeType,
    required this.fileType,
    required this.size,
    this.description,
  });

  factory FileAttachmentInfo.fromJson(Map<String, dynamic> json) {
    return FileAttachmentInfo(
      path: json['path'] as String,
      filename: json['filename'] as String,
      mimeType: json['mimeType'] as String,
      fileType: json['fileType'] as String,
      size: json['size'] as int,
      description: json['description'] as String?,
    );
  }

  /// 이미지 파일인지 확인
  bool get isImage => fileType == 'image';

  /// 마크다운 파일인지 확인
  bool get isMarkdown => fileType == 'markdown';

  /// 텍스트 파일인지 확인
  bool get isText => fileType == 'text';

  /// 사람이 읽기 좋은 파일 크기
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 다운로드 상태
enum FileDownloadState {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

/// 파일 첨부 메시지 (Claude가 사용자에게 파일을 보낼 때)
class FileAttachmentMessage implements ClaudeMessage {
  @override
  final String id;
  final FileAttachmentInfo file;
  final FileDownloadState downloadState;
  @override
  final int timestamp;

  const FileAttachmentMessage({
    required this.id,
    required this.file,
    this.downloadState = FileDownloadState.notDownloaded,
    required this.timestamp,
  });

  FileAttachmentMessage copyWith({
    String? id,
    FileAttachmentInfo? file,
    FileDownloadState? downloadState,
    int? timestamp,
  }) {
    return FileAttachmentMessage(
      id: id ?? this.id,
      file: file ?? this.file,
      downloadState: downloadState ?? this.downloadState,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// User response message (permission or question answer)
class UserResponseMessage implements ClaudeMessage {
  @override
  final String id;
  final String responseType; // 'permission' or 'question'
  final String content;
  @override
  final int timestamp;

  const UserResponseMessage({
    required this.id,
    required this.responseType,
    required this.content,
    required this.timestamp,
  });

  UserResponseMessage copyWith({
    String? id,
    String? responseType,
    String? content,
    int? timestamp,
  }) {
    return UserResponseMessage(
      id: id ?? this.id,
      responseType: responseType ?? this.responseType,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Helper to parse tool input for display
class ToolInputParser {
  static ({String desc, String cmd}) parse(String toolName, Map<String, dynamic> input) {
    switch (toolName) {
      case 'Bash':
        return (
          desc: input['description'] as String? ?? '',
          cmd: input['command'] as String? ?? '',
        );
      case 'Read':
        return (
          desc: 'Read file',
          cmd: input['file_path'] as String? ?? '',
        );
      case 'Edit':
        return (
          desc: 'Edit file',
          cmd: input['file_path'] as String? ?? '',
        );
      case 'Write':
        return (
          desc: 'Write file',
          cmd: input['file_path'] as String? ?? '',
        );
      case 'Glob':
        final path = input['path'] as String?;
        return (
          desc: path != null ? 'Search in $path' : 'Search files',
          cmd: input['pattern'] as String? ?? '',
        );
      case 'Grep':
        final path = input['path'] as String?;
        return (
          desc: path != null ? 'Search in $path' : 'Search content',
          cmd: input['pattern'] as String? ?? '',
        );
      case 'WebFetch':
        return (
          desc: 'Fetch URL',
          cmd: input['url'] as String? ?? '',
        );
      case 'WebSearch':
        return (
          desc: 'Web search',
          cmd: input['query'] as String? ?? '',
        );
      case 'Task':
        final prompt = input['prompt'] as String? ?? '';
        return (
          desc: input['description'] as String? ?? 'Run task',
          cmd: prompt.length > 100 ? '${prompt.substring(0, 100)}...' : prompt,
        );
      case 'TodoWrite':
        final todosRaw = input['todos'];
        final count = todosRaw is List ? todosRaw.length : 0;
        return (
          desc: 'Update todos',
          cmd: '$count items',
        );
      default:
        final firstVal = input.values.whereType<String>().firstOrNull;
        return (
          desc: toolName,
          cmd: firstVal != null && firstVal.length > 80 ? firstVal.substring(0, 80) : (firstVal ?? ''),
        );
    }
  }
}
