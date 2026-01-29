import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/claude_message.dart';
import '../../data/services/image_cache_service.dart' as cache;
import 'relay_provider.dart';

/// 파일별 다운로드 상태 Provider
final fileDownloadStateProvider = Provider.family<FileDownloadState, String>((ref, filename) {
  final downloads = ref.watch(fileDownloadProvider);
  final state = downloads[filename] ?? FileDownloadState.notDownloaded;
  print('[FileDownload] fileDownloadStateProvider($filename) returning: $state');
  return state;
});

/// 파일 다운로드 상태 관리 Notifier
class FileDownloadNotifier extends StateNotifier<Map<String, FileDownloadState>> {
  final Ref _ref;
  StreamSubscription? _downloadSubscription;

  FileDownloadNotifier(this._ref) : super({}) {
    print('[FileDownload] FileDownloadNotifier created');
    _listenToDownloads();
  }

  void _listenToDownloads() {
    final blobService = _ref.read(blobTransferServiceProvider);
    print('[FileDownload] Setting up downloadCompleteStream listener');
    print('[FileDownload] BlobService instance: ${blobService.hashCode}');

    // 기존 구독 취소
    _downloadSubscription?.cancel();

    // 다운로드 완료 리스닝
    _downloadSubscription = blobService.downloadCompleteStream.listen((event) {
      final filename = event.filename;
      print('[FileDownload] downloadCompleteStream received: $filename');
      print('[FileDownload] Current state keys: ${state.keys.toList()}');
      print('[FileDownload] state.containsKey($filename): ${state.containsKey(filename)}');

      if (state.containsKey(filename)) {
        print('[FileDownload] Updating state to downloaded');
        final newState = Map<String, FileDownloadState>.from(state);
        newState[filename] = FileDownloadState.downloaded;
        state = newState;
      } else {
        // state에 없어도 다운로드 완료로 추가 (캐시에서 직접 완료된 경우)
        print('[FileDownload] Adding filename to state as downloaded');
        final newState = Map<String, FileDownloadState>.from(state);
        newState[filename] = FileDownloadState.downloaded;
        state = newState;
      }
    });
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  /// 다운로드 시작
  void startDownload({
    required String filename,
    required int targetDeviceId,
    required String conversationId,
    required String filePath,
  }) {
    print('[FileDownload] startDownload called: $filename, device: $targetDeviceId');

    // 이미 다운로드 중이거나 완료된 경우 무시
    final currentState = state[filename];
    if (currentState == FileDownloadState.downloading ||
        currentState == FileDownloadState.downloaded) {
      print('[FileDownload] Skipped - already $currentState');
      return;
    }

    // 캐시에 이미 있는지 확인
    if (cache.imageCache.contains(filename)) {
      final newState = Map<String, FileDownloadState>.from(state);
      newState[filename] = FileDownloadState.downloaded;
      state = newState;
      return;
    }

    // 다운로드 중 상태로 변경
    final newState = Map<String, FileDownloadState>.from(state);
    newState[filename] = FileDownloadState.downloading;
    state = newState;

    // 다운로드 요청
    final blobService = _ref.read(blobTransferServiceProvider);
    print('[FileDownload] startDownload BlobService instance: ${blobService.hashCode}');
    blobService.requestFile(
      targetDeviceId: targetDeviceId,
      conversationId: conversationId,
      filename: filename,
      filePath: filePath,
    );
  }

  /// 다운로드 실패 처리
  void setFailed(String filename) {
    final newState = Map<String, FileDownloadState>.from(state);
    newState[filename] = FileDownloadState.failed;
    state = newState;
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
