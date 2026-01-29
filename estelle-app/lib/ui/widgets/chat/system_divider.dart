import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/claude_message.dart';

/// Claude 중단 메시지를 빨간 구분선으로 표시
class ClaudeAbortedDivider extends StatelessWidget {
  final ClaudeAbortedMessage message;

  const ClaudeAbortedDivider({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.statusError.withOpacity(0.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              message.displayText,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.statusError.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.statusError.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
