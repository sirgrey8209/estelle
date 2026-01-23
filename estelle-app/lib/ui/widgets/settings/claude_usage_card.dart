import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/claude_usage.dart';
import '../../../state/providers/settings_provider.dart';

/// Claude 사용량 표시 카드
class ClaudeUsageCard extends ConsumerWidget {
  const ClaudeUsageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(claudeUsageProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NordColors.nord0,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Claude Usage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: NordColors.nord5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: usageAsync.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(NordColors.nord4),
                        ),
                      )
                    : const Icon(Icons.refresh, size: 20, color: NordColors.nord4),
                onPressed: usageAsync.isLoading
                    ? null
                    : () => ref.read(claudeUsageProvider.notifier).requestUsage(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Usage gauges
          usageAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(NordColors.nord10),
                ),
              ),
            ),
            error: (error, _) => _ErrorMessage(
              message: error.toString(),
              onRetry: () =>
                  ref.read(claudeUsageProvider.notifier).requestUsage(),
            ),
            data: (usage) {
              if (usage.hasError) {
                return _ErrorMessage(
                  message: usage.error!,
                  onRetry: () =>
                      ref.read(claudeUsageProvider.notifier).requestUsage(),
                );
              }
              return _UsageGauges(usage: usage);
            },
          ),
        ],
      ),
    );
  }
}

class _UsageGauges extends StatelessWidget {
  final ClaudeUsage usage;

  const _UsageGauges({required this.usage});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _UsageGauge(
          label: '5h',
          percentage: usage.usage5h,
          resetsAt: usage.resets5h,
        ),
        const SizedBox(width: 24),
        _UsageGauge(
          label: '7d',
          percentage: usage.usage7d,
          resetsAt: usage.resets7d,
        ),
      ],
    );
  }
}

class _UsageGauge extends StatelessWidget {
  final String label;
  final double percentage;
  final DateTime? resetsAt;

  const _UsageGauge({
    required this.label,
    required this.percentage,
    this.resetsAt,
  });

  Color _getColor(double pct) {
    if (pct >= 90) return NordColors.nord11;
    if (pct >= 70) return NordColors.nord12;
    if (pct >= 50) return NordColors.nord13;
    return NordColors.nord14;
  }

  String _formatResetTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = time.difference(now);
    if (diff.isNegative) return 'reset';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'soon';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(percentage);
    final clampedPercentage = percentage.clamp(0.0, 100.0);

    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  backgroundColor: NordColors.nord2,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(NordColors.nord2),
                ),
              ),
              // Progress circle
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: clampedPercentage / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              // Percentage text
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: NordColors.nord4,
          ),
        ),
        if (resetsAt != null) ...[
          const SizedBox(height: 2),
          Text(
            _formatResetTime(resetsAt),
            style: const TextStyle(
              fontSize: 11,
              color: NordColors.nord3,
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorMessage({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: NordColors.nord11, size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: NordColors.nord11, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('재시도'),
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: NordColors.nord10,
            ),
          ),
        ],
      ),
    );
  }
}
