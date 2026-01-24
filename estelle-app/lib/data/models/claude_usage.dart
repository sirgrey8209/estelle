/// Claude 사용량 데이터 모델 (Pylon 누적 기반)
class ClaudeUsage {
  final double totalCostUsd;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCacheReadTokens;
  final int totalCacheCreationTokens;
  final int sessionCount;
  final DateTime? lastUpdated;

  const ClaudeUsage({
    required this.totalCostUsd,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalCacheReadTokens,
    required this.totalCacheCreationTokens,
    required this.sessionCount,
    this.lastUpdated,
  });

  factory ClaudeUsage.fromPylonStatus(Map<String, dynamic> json) {
    return ClaudeUsage(
      totalCostUsd: (json['totalCostUsd'] as num?)?.toDouble() ?? 0.0,
      totalInputTokens: (json['totalInputTokens'] as num?)?.toInt() ?? 0,
      totalOutputTokens: (json['totalOutputTokens'] as num?)?.toInt() ?? 0,
      totalCacheReadTokens: (json['totalCacheReadTokens'] as num?)?.toInt() ?? 0,
      totalCacheCreationTokens: (json['totalCacheCreationTokens'] as num?)?.toInt() ?? 0,
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,
    );
  }

  factory ClaudeUsage.empty() {
    return const ClaudeUsage(
      totalCostUsd: 0.0,
      totalInputTokens: 0,
      totalOutputTokens: 0,
      totalCacheReadTokens: 0,
      totalCacheCreationTokens: 0,
      sessionCount: 0,
    );
  }

  /// 총 토큰 수
  int get totalTokens => totalInputTokens + totalOutputTokens;

  /// 캐시 효율 (%)
  double get cacheEfficiency {
    if (totalInputTokens == 0) return 0;
    return (totalCacheReadTokens / totalInputTokens) * 100;
  }

  /// 포맷된 비용
  String get formattedCost => '\$${totalCostUsd.toStringAsFixed(4)}';

  /// 포맷된 토큰 (K 단위)
  String get formattedTokens {
    if (totalTokens >= 1000000) {
      return '${(totalTokens / 1000000).toStringAsFixed(1)}M';
    } else if (totalTokens >= 1000) {
      return '${(totalTokens / 1000).toStringAsFixed(1)}K';
    }
    return totalTokens.toString();
  }
}
