import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart';

/// APK 다운로드 및 설치 서비스
class ApkInstaller {
  static final Dio _dio = Dio();

  /// APK 다운로드 및 설치
  /// [url] APK 다운로드 URL
  /// [onProgress] 다운로드 진행률 콜백 (0.0 ~ 1.0)
  /// [onStatusChange] 상태 변경 콜백
  static Future<bool> downloadAndInstall({
    required String url,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatusChange,
  }) async {
    try {
      onStatusChange?.call('다운로드 준비 중...');

      // 다운로드 경로 설정
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        throw Exception('외부 저장소를 찾을 수 없습니다');
      }

      final filePath = '${dir.path}/estelle-update.apk';
      final file = File(filePath);

      // 기존 파일 삭제
      if (await file.exists()) {
        await file.delete();
      }

      onStatusChange?.call('다운로드 중...');

      // APK 다운로드
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress?.call(progress);
          }
        },
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      // 파일 존재 확인
      if (!await file.exists()) {
        throw Exception('다운로드된 파일을 찾을 수 없습니다');
      }

      final fileSize = await file.length();
      if (fileSize < 1000) {
        throw Exception('다운로드된 파일이 유효하지 않습니다');
      }

      onStatusChange?.call('설치 화면 열기...');

      // APK 설치 화면 열기
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done) {
        debugPrint('OpenFilex result: ${result.type} - ${result.message}');
        // 설치 화면이 열리지 않아도 파일은 다운로드됨
        onStatusChange?.call('설치 화면을 수동으로 열어주세요');
        return false;
      }

      onStatusChange?.call('설치 화면이 열렸습니다');
      return true;
    } catch (e) {
      debugPrint('APK 설치 오류: $e');
      onStatusChange?.call('오류: $e');
      return false;
    }
  }
}
