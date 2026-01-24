import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/claude_usage.dart';
import '../../../state/providers/settings_provider.dart';

/// Claude 사용량 표시 카드 (Pylon 누적 기반)
class ClaudeUsageCard extends ConsumerWidget {
  const ClaudeUsageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(claudeUsageProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NordColors.nord1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NordColors.nord3, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: NordColors.nord10,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Claude Usage',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NordColors.nord5,
                ),
              ),
              const Spacer(),
              // 세션 카운트
              if (usage.sessionCount > 0)
                Text(
                  '${usage.sessionCount} sessions',
                  style: const TextStyle(
                    fontSize: 11,
                    color: NordColors.nord4,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 사용량 정보
          _UsageStats(usage: usage),
        ],
      ),
    );
  }
}

class _UsageStats extends StatelessWidget {
  final ClaudeUsage usage;

  const _UsageStats({required this.usage});

  @override
  Widget build(BuildContext context) {
    if (usage.sessionCount == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No usage data yet',
            style: TextStyle(
              fontSize: 12,
              color: NordColors.nord4,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        // 비용
        Expanded(
          child: _StatItem(
            icon: Icons.attach_money,
            label: 'Cost',
            value: usage.formattedCost,
            color: NordColors.nord13,
          ),
        ),
        // 토큰
        Expanded(
          child: _StatItem(
            icon: Icons.token,
            label: 'Tokens',
            value: usage.formattedTokens,
            color: NordColors.nord10,
          ),
        ),
        // 캐시 효율
        Expanded(
          child: _StatItem(
            icon: Icons.cached,
            label: 'Cache',
            value: '${usage.cacheEfficiency.toStringAsFixed(0)}%',
            color: NordColors.nord14,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: NordColors.nord4,
          ),
        ),
      ],
    );
  }
}
