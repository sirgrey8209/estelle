import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

/// 텍스트 파일 뷰어
class TextViewer extends StatelessWidget {
  final Uint8List data;
  final String filename;

  const TextViewer({
    super.key,
    required this.data,
    required this.filename,
  });

  String _decodeText() {
    try {
      return utf8.decode(data);
    } catch (e) {
      // UTF-8 실패 시 latin1로 시도
      try {
        return latin1.decode(data);
      } catch (e2) {
        return '텍스트를 디코딩할 수 없습니다';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _decodeText();

    return Container(
      color: NordColors.nord1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            color: NordColors.nord4,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
