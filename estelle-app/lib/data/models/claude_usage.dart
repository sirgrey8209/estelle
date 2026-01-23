/// Claude 사용량 데이터 모델
class ClaudeUsage {
  final double usage5h;
  final double usage7d;
  final DateTime? resets5h;
  final DateTime? resets7d;
  final String? error;
  final DateTime fetchedAt;

  const ClaudeUsage({
    required this.usage5h,
    required this.usage7d,
    this.resets5h,
    this.resets7d,
    this.error,
    required this.fetchedAt,
  });

  factory ClaudeUsage.fromJson(Map<String, dynamic> json) {
    return ClaudeUsage(
      usage5h: (json['usage5h'] as num?)?.toDouble() ?? 0.0,
      usage7d: (json['usage7d'] as num?)?.toDouble() ?? 0.0,
      resets5h: json['resets5h'] != null
          ? DateTime.tryParse(json['resets5h'] as String)
          : null,
      resets7d: json['resets7d'] != null
          ? DateTime.tryParse(json['resets7d'] as String)
          : null,
      error: json['error'] as String?,
      fetchedAt: DateTime.now(),
    );
  }

  factory ClaudeUsage.empty() {
    return ClaudeUsage(
      usage5h: 0.0,
      usage7d: 0.0,
      fetchedAt: DateTime.now(),
    );
  }

  factory ClaudeUsage.error(String message) {
    return ClaudeUsage(
      usage5h: 0.0,
      usage7d: 0.0,
      error: message,
      fetchedAt: DateTime.now(),
    );
  }

  bool get hasError => error != null;
}
