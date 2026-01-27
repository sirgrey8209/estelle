import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../state/providers/image_upload_provider.dart';
import '../../../state/providers/relay_provider.dart';
import '../../../data/services/blob_transfer_service.dart';
import '../../../data/services/image_cache_service.dart' as cache;

/// 업로드 중인 이미지 버블
class UploadingImageBubble extends ConsumerWidget {
  final UploadingImage upload;

  const UploadingImageBubble({super.key, required this.upload});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blobService = ref.watch(blobTransferServiceProvider);

    // StreamBuilder로 실시간 프로그레스 업데이트
    return StreamBuilder<BlobTransfer>(
      stream: blobService.progressStream.where((t) => t.blobId == upload.blobId),
      builder: (context, snapshot) {
        final transfer = snapshot.data ?? blobService.getTransfer(upload.blobId);

        // 프로그레스 계산
        final progress = transfer?.progress ?? upload.progress;
        final isCompleted = upload.status == ImageUploadStatus.completed;
        final isFailed = upload.status == ImageUploadStatus.failed;

        return _buildBubble(context, progress, isCompleted, isFailed);
      },
    );
  }

  Widget _buildBubble(BuildContext context, double progress, bool isCompleted, bool isFailed) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: NordColors.nord3,
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(
              color: isFailed ? NordColors.nord11 : NordColors.nord10,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이미지 미리보기
            Row(
              children: [
                _buildImagePreview(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upload.filename,
                        style: const TextStyle(
                          fontSize: 12,
                          color: NordColors.nord5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (isFailed)
                        const Text(
                          '업로드 실패',
                          style: TextStyle(
                            fontSize: 11,
                            color: NordColors.nord11,
                          ),
                        )
                      else if (isCompleted)
                        const Text(
                          '업로드 완료',
                          style: TextStyle(
                            fontSize: 11,
                            color: NordColors.nord14,
                          ),
                        )
                      else
                        Text(
                          '업로드 중... ${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: NordColors.nord4,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // 프로그레스 바
            if (!isCompleted && !isFailed) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: NordColors.nord2,
                  valueColor: const AlwaysStoppedAnimation<Color>(NordColors.nord8),
                  minHeight: 4,
                ),
              ),
            ],
            // 같이 보낸 메시지
            if (upload.message != null && upload.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                upload.message!,
                style: const TextStyle(
                  fontSize: 13,
                  color: NordColors.nord6,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    // 캐시에서 이미지 가져오기
    final Uint8List? bytes = cache.imageCache.get(upload.filename);

    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          bytes,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _buildPlaceholder(),
        ),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: NordColors.nord2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NordColors.nord3),
      ),
      child: const Icon(
        Icons.image,
        color: NordColors.nord4,
        size: 24,
      ),
    );
  }
}
