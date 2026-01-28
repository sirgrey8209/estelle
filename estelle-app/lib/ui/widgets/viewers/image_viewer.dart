import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

/// 이미지 뷰어 (확대/축소 지원)
class ImageViewer extends StatelessWidget {
  final Uint8List data;
  final String filename;

  const ImageViewer({
    super.key,
    required this.data,
    required this.filename,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NordColors.nord1,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.memory(
            data,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 48,
                      color: NordColors.nord11,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '이미지를 표시할 수 없습니다',
                      style: const TextStyle(
                        fontSize: 14,
                        color: NordColors.nord4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filename,
                      style: const TextStyle(
                        fontSize: 12,
                        color: NordColors.nord3,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
