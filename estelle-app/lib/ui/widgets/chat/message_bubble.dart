import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/claude_message.dart';
import '../../../data/services/image_cache_service.dart' as cache;
import '../../../state/providers/relay_provider.dart';
import '../../../state/providers/workspace_provider.dart';

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

/// 첨부 이미지 위젯 (캐시 기반 - 모든 플랫폼 호환)
class _AttachmentImage extends ConsumerStatefulWidget {
  final AttachmentInfo attachment;

  const _AttachmentImage({required this.attachment});

  @override
  ConsumerState<_AttachmentImage> createState() => _AttachmentImageState();
}

class _AttachmentImageState extends ConsumerState<_AttachmentImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _downloadRequested = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  void _loadImage() {
    final filename = widget.attachment.filename;

    // 캐시에서 먼저 확인
    final cached = cache.imageCache.get(filename);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _imageBytes = cached;
          _isLoading = false;
        });
      }
      return;
    }

    // 캐시에 없으면 로딩 상태 표시
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _requestDownload() {
    if (_downloadRequested) return;
    _downloadRequested = true;

    final blobService = ref.read(blobTransferServiceProvider);
    final selectedItem = ref.read(selectedItemProvider);

    if (selectedItem == null) {
      return;
    }

    // 다운로드 요청
    blobService.requestImage(
      targetDeviceId: selectedItem.deviceId,
      conversationId: selectedItem.itemId,
      filename: widget.attachment.filename,
    );

    // 다운로드 완료 리스닝
    blobService.downloadCompleteStream.listen((event) {
      if (event.filename == widget.attachment.filename && mounted) {
        setState(() {
          _imageBytes = event.bytes;
        });
      }
    });

    setState(() {
      _isLoading = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingPlaceholder();
    }

    if (_imageBytes != null) {
      return GestureDetector(
        onTap: () => _showFullImage(context, _imageBytes!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 200,
              maxHeight: 200,
            ),
            child: Image.memory(
              _imageBytes!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) {
                return _buildPlaceholder();
              },
            ),
          ),
        ),
      );
    }

    // 캐시에 없으면 다운로드 버튼 표시
    return _buildDownloadPlaceholder();
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        color: NordColors.nord2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NordColors.nord3),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: NordColors.nord4,
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadPlaceholder() {
    return GestureDetector(
      onTap: _requestDownload,
      child: Container(
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
            const Icon(Icons.download, color: NordColors.nord4, size: 24),
            const SizedBox(height: 4),
            Text(
              widget.attachment.filename,
              style: const TextStyle(
                fontSize: 10,
                color: NordColors.nord4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
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
          const Icon(Icons.broken_image, color: NordColors.nord11, size: 24),
          const SizedBox(height: 4),
          Text(
            widget.attachment.filename,
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

  void _showFullImage(BuildContext context, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(bytes),
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
