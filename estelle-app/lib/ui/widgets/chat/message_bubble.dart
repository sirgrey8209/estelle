import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class MessageBubble extends StatelessWidget {
  final Widget child;
  final bool isUser;
  final Color? borderColor;
  final Color? backgroundColor;

  const MessageBubble._({
    required this.child,
    this.isUser = false,
    this.borderColor,
    this.backgroundColor,
  });

  factory MessageBubble.user({required String content}) {
    return MessageBubble._(
      isUser: true,
      borderColor: NordColors.nord10,
      backgroundColor: NordColors.nord3,
      child: SelectableText(
        content,
        style: const TextStyle(
          fontSize: 13,
          color: NordColors.nord6,
          height: 1.4,
        ),
      ),
    );
  }

  factory MessageBubble.sending({required String content}) {
    return MessageBubble._(
      isUser: true,
      borderColor: NordColors.nord3,
      backgroundColor: NordColors.nord2,
      child: Opacity(
        opacity: 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                color: NordColors.nord5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '전송 중...',
              style: TextStyle(
                fontSize: 11,
                color: NordColors.nord4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  factory MessageBubble.assistant({required String content}) {
    return MessageBubble._(
      child: SelectableText(
        content,
        style: const TextStyle(
          fontSize: 13,
          color: NordColors.nord4,
          height: 1.4,
        ),
      ),
    );
  }

  factory MessageBubble.error({required String error}) {
    return MessageBubble._(
      borderColor: NordColors.nord11,
      backgroundColor: NordColors.nord1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Flexible(
            child: SelectableText(
              error,
              style: const TextStyle(
                fontSize: 13,
                color: NordColors.nord11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  factory MessageBubble.response({
    required String responseType,
    required String content,
  }) {
    final isPermission = responseType == 'permission';
    final parts = content.split(' (');
    final toolOrAnswer = parts.first;
    final decision = parts.length > 1 ? parts.last.replaceAll(')', '') : null;
    final isAllowed = decision == '승인됨';

    return MessageBubble._(
      isUser: true,
      backgroundColor: NordColors.nord2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPermission) ...[
            Text(
              toolOrAnswer,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: NordColors.nord4,
              ),
            ),
            if (decision != null) ...[
              const SizedBox(width: 4),
              Text(
                '($decision)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isAllowed ? NordColors.nord14 : NordColors.nord11,
                ),
              ),
            ],
          ] else
            Text(
              content,
              style: const TextStyle(
                fontSize: 12,
                color: NordColors.nord5,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: backgroundColor != null ? 10 : 0,
          vertical: backgroundColor != null ? 6 : 0,
        ),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: borderColor != null
              ? Border(left: BorderSide(color: borderColor!, width: 2))
              : null,
        ),
        child: child,
      ),
    );
  }
}
