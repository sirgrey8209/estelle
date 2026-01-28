import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/claude_message.dart';
import '../../../data/services/image_cache_service.dart' as cache;
import 'image_viewer.dart';
import 'markdown_viewer.dart';
import 'text_viewer.dart';

/// 파일 뷰어 열기
void showFileViewer(BuildContext context, WidgetRef ref, FileAttachmentInfo file) {
  // 캐시에서 파일 데이터 가져오기
  final data = cache.imageCache.get(file.filename);

  if (data == null) {
    // 데이터가 없으면 에러 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('파일을 먼저 다운로드해주세요'),
        backgroundColor: NordColors.nord11,
      ),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => FileViewerDialog(file: file, data: data),
  );
}

/// 파일 뷰어 다이얼로그
class FileViewerDialog extends StatelessWidget {
  final FileAttachmentInfo file;
  final Uint8List data;

  const FileViewerDialog({
    super.key,
    required this.file,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NordColors.nord0,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            _buildHeader(context),
            // 구분선
            const Divider(height: 1, color: NordColors.nord2),
            // 콘텐츠
            Flexible(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            _getFileIcon(),
            size: 20,
            color: _getFileIconColor(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.filename,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: NordColors.nord5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  file.formattedSize,
                  style: const TextStyle(
                    fontSize: 11,
                    color: NordColors.nord4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: NordColors.nord4),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (file.isImage) {
      return ImageViewer(data: data, filename: file.filename);
    } else if (file.isMarkdown) {
      return MarkdownViewer(data: data, filename: file.filename);
    } else {
      return TextViewer(data: data, filename: file.filename);
    }
  }

  IconData _getFileIcon() {
    if (file.isImage) return Icons.image;
    if (file.isMarkdown) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileIconColor() {
    if (file.isImage) return NordColors.nord15;
    if (file.isMarkdown) return NordColors.nord8;
    return NordColors.nord4;
  }
}
