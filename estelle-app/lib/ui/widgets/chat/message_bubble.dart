import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/claude_message.dart';

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

  factory MessageBubble.user({
    required String content,
    List<AttachmentInfo>? attachments,
  }) {
    return MessageBubble._(
      isUser: true,
      borderColor: NordColors.nord10,
      backgroundColor: NordColors.nord3,
      child: _UserContent(content: content, attachments: attachments),
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

/// 사용자 메시지 내용 (텍스트 + 이미지)
class _UserContent extends StatelessWidget {
  final String content;
  final List<AttachmentInfo>? attachments;

  const _UserContent({required this.content, this.attachments});

  @override
  Widget build(BuildContext context) {
    final hasAttachments = attachments != null && attachments!.isNotEmpty;
    final hasText = content.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 이미지들
        if (hasAttachments)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attachments!.map((attachment) {
              return _AttachmentImage(attachment: attachment);
            }).toList(),
          ),

        // 텍스트
        if (hasAttachments && hasText)
          const SizedBox(height: 8),
        if (hasText)
          SelectableText(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: NordColors.nord6,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}

/// 첨부 이미지 위젯
class _AttachmentImage extends StatelessWidget {
  final AttachmentInfo attachment;

  const _AttachmentImage({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final localPath = attachment.localPath;

    // 로컬 파일이 있으면 표시
    if (localPath != null) {
      final file = File(localPath);
      if (file.existsSync()) {
        return GestureDetector(
          onTap: () => _showFullImage(context, file),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 200,
                maxHeight: 200,
              ),
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) {
                  return _buildPlaceholder();
                },
              ),
            ),
          ),
        );
      }
    }

    // 파일이 없으면 플레이스홀더 표시 (다운로드 필요)
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        color: NordColors.nord2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NordColors.nord3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image, color: NordColors.nord4, size: 24),
          const SizedBox(height: 4),
          Text(
            attachment.filename,
            style: const TextStyle(
              fontSize: 10,
              color: NordColors.nord4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: NordColors.nord6),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: NordColors.nord0.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
