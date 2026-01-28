import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/claude_message.dart';
import '../../data/services/image_cache_service.dart' as cache;
import 'relay_provider.dart';

/// 파일별 다운로드 상태 Provider
final fileDownloadStateProvider = Provider.family<FileDownloadState, String>((ref, filename) {
  final downloads = ref.watch(fileDownloadProvider);
  return downloads[filename] ?? FileDownloadState.notDownloaded;
});

/// 파일 다운로드 상태 관리 Notifier
class FileDownloadNotifier extends StateNotifier<Map<String, FileDownloadState>> {
  final Ref _ref;

  FileDownloadNotifier(this._ref) : super({}) {
    _listenToDownloads();
  }

  void _listenToDownloads() {
    final blobService = _ref.read(blobTransferServiceProvider);

    // 다운로드 완료 리스닝
    blobService.downloadCompleteStream.listen((event) {
      final filename = event.filename;
      if (state.containsKey(filename)) {
        state = {...state, filename: FileDownloadState.downloaded};
      }
    });
  }

  /// 다운로드 시작
  void startDownload({
    required String filename,
    required int targetDeviceId,
    required String conversationId,
    required String filePath,
  }) {
    // 이미 다운로드 중이거나 완료된 경우 무시
    final currentState = state[filename];
    if (currentState == FileDownloadState.downloading ||
        currentState == FileDownloadState.downloaded) {
      return;
    }

    // 캐시에 이미 있는지 확인
    if (cache.imageCache.contains(filename)) {
      state = {...state, filename: FileDownloadState.downloaded};
      return;
    }

    // 다운로드 중 상태로 변경
    state = {...state, filename: FileDownloadState.downloading};

    // 다운로드 요청
    final blobService = _ref.read(blobTransferServiceProvider);
    blobService.requestFile(
      targetDeviceId: targetDeviceId,
      conversationId: conversationId,
      filename: filename,
      filePath: filePath,
    );
  }

  /// 다운로드 실패 처리
  void setFailed(String filename) {
    state = {...state, filename: FileDownloadState.failed};
  }

  /// 상태 초기화
  void reset(String filename) {
    final newState = Map<String, FileDownloadState>.from(state);
    newState.remove(filename);
    state = newState;
  }
}

final fileDownloadProvider =
    StateNotifierProvider<FileDownloadNotifier, Map<String, FileDownloadState>>((ref) {
  return FileDownloadNotifier(ref);
});

/// 다운로드된 파일 데이터 가져오기
Uint8List? getDownloadedFileData(String filename) {
  return cache.imageCache.get(filename);
}
