import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

/// 마크다운 뷰어
/// TODO: flutter_markdown 패키지 추가 후 렌더링 지원
class MarkdownViewer extends StatelessWidget {
  final Uint8List data;
  final String filename;

  const MarkdownViewer({
    super.key,
    required this.data,
    required this.filename,
  });

  String _decodeText() {
    try {
      return utf8.decode(data);
    } catch (e) {
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

    // 현재는 간단한 텍스트 표시
    // TODO: flutter_markdown 패키지로 렌더링 지원
    return Container(
      color: NordColors.nord1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: NordColors.nord4,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
