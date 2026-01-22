import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/claude_message.dart';

class ResultInfo extends StatelessWidget {
  final ResultInfoMessage message;

  const ResultInfo({super.key, required this.message});

  String _formatNumber(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final totalTokens = message.inputTokens + message.outputTokens;
    final durationSec = (message.durationMs / 1000).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: NordColors.nord1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            durationSec,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: NordColors.nord4,
            ),
          ),
          Text(
            's',
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: NordColors.nord4.withOpacity(0.8),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '·',
            style: TextStyle(
              color: NordColors.nord3,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatNumber(totalTokens),
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: NordColors.nord4,
            ),
          ),
          Text(
            ' tokens',
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: NordColors.nord4.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
