/// JSON에서 List를 안전하게 추출
List<dynamic>? _safeList(dynamic value) {
  if (value == null) return null;
  if (value is List) return value;
  return null;
}

/// Base class for pending requests
sealed class PendingRequest {
  String get toolUseId;
}

/// Permission request for tool execution
class PermissionRequest implements PendingRequest {
  @override
  final String toolUseId;
  final String toolName;
  final Map<String, dynamic> toolInput;

  const PermissionRequest({
    required this.toolUseId,
    required this.toolName,
    required this.toolInput,
  });

  PermissionRequest copyWith({
    String? toolUseId,
    String? toolName,
    Map<String, dynamic>? toolInput,
  }) {
    return PermissionRequest(
      toolUseId: toolUseId ?? this.toolUseId,
      toolName: toolName ?? this.toolName,
      toolInput: toolInput ?? this.toolInput,
    );
  }
}

/// Question with options
class QuestionRequest implements PendingRequest {
  @override
  final String toolUseId;
  final List<QuestionItem> questions;
  final Map<int, String> answers;

  const QuestionRequest({
    required this.toolUseId,
    required this.questions,
    this.answers = const {},
  });

  QuestionRequest copyWith({
    String? toolUseId,
    List<QuestionItem>? questions,
    Map<int, String>? answers,
  }) {
    return QuestionRequest(
      toolUseId: toolUseId ?? this.toolUseId,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
    );
  }
}

/// Question item model
class QuestionItem {
  final String question;
  final String header;
  final List<String> options;
  final bool multiSelect;

  const QuestionItem({
    required this.question,
    this.header = 'Question',
    this.options = const [],
    this.multiSelect = false,
  });

  QuestionItem copyWith({
    String? question,
    String? header,
    List<String>? options,
    bool? multiSelect,
  }) {
    return QuestionItem(
      question: question ?? this.question,
      header: header ?? this.header,
      options: options ?? this.options,
      multiSelect: multiSelect ?? this.multiSelect,
    );
  }

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    return QuestionItem(
      question: json['question'] as String? ?? '',
      header: json['header'] as String? ?? 'Question',
      options: (_safeList(json['options']))
          ?.map((e) => e.toString())
          .toList() ?? [],
      multiSelect: json['multiSelect'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'header': header,
    'options': options,
    'multiSelect': multiSelect,
  };
}
