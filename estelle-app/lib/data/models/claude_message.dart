/// Base class for Claude messages
sealed class ClaudeMessage {
  String get id;
  int get timestamp;
}

/// User text message
class UserTextMessage implements ClaudeMessage {
  @override
  final String id;
  final String content;
  @override
  final int timestamp;

  const UserTextMessage({
    required this.id,
    required this.content,
    required this.timestamp,
  });

  UserTextMessage copyWith({
    String? id,
    String? content,
    int? timestamp,
  }) {
    return UserTextMessage(
      id: id ?? this.id,
      content: content ?? this.content,
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
