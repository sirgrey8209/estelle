import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/pending_request.dart';

class PermissionRequestView extends StatelessWidget {
  final PermissionRequest request;
  final ValueChanged<String> onRespond;

  const PermissionRequestView({
    super.key,
    required this.request,
    required this.onRespond,
  });

  String _formatToolInput() {
    final input = request.toolInput;
    if (input.isEmpty) return '';

    // 주요 필드 추출
    final command = input['command'] as String?;
    final filePath = input['file_path'] as String?;
    final pattern = input['pattern'] as String?;
    final url = input['url'] as String?;

    if (command != null) return command;
    if (filePath != null) return filePath;
    if (pattern != null) return pattern;
    if (url != null) return url;

    // 첫 번째 문자열 값 반환
    for (final entry in input.entries) {
      if (entry.value is String && (entry.value as String).isNotEmpty) {
        return '${entry.key}: ${entry.value}';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final details = _formatToolInput();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: NordColors.nord12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '권한 요청',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: NordColors.nord0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                request.toolName,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: NordColors.nord5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // Details (command, file_path, etc.)
        if (details.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: NordColors.nord0,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              details,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: NordColors.nord4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Action buttons
        Row(
          children: [
            _ActionButton(
              label: '승인',
              color: NordColors.nord14,
              textColor: NordColors.nord0,
              onPressed: () => onRespond('allow'),
            ),
            const SizedBox(width: 10),
            _ActionButton(
              label: '거부',
              color: NordColors.nord11,
              textColor: NordColors.nord6,
              onPressed: () => onRespond('deny'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
