import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'relay_service.dart';
import 'image_cache_service.dart';

/// Blob 전송 상태
enum BlobTransferState {
  pending,
  uploading,
  downloading,
  waitingAck,  // 청크 전송 완료, Pylon 응답 대기
  completed,
  failed,
}

/// 전송 중인 Blob 정보
class BlobTransfer {
  final String blobId;
  final String filename;
  final String mimeType;
  final int totalSize;
  final int chunkSize;
  final int totalChunks;
  final Map<String, dynamic> context;
  final bool isUpload;

  BlobTransferState state = BlobTransferState.pending;
  int processedChunks = 0;
  List<Uint8List> chunks = [];
  Uint8List? bytes;  // 완료된 데이터
  String? pylonPath;  // Pylon에서 저장된 경로
  String? error;

  BlobTransfer({
    required this.blobId,
    required this.filename,
    required this.mimeType,
    required this.totalSize,
    required this.chunkSize,
    required this.totalChunks,
    required this.context,
    required this.isUpload,
  });

  double get progress => totalChunks > 0 ? processedChunks / totalChunks : 0;
}

/// 업로드 완료 이벤트
class BlobUploadCompleteEvent {
  final String blobId;
  final String filename;
  final String pylonPath;
  final String conversationId;
  final String? thumbnailBase64;  // Pylon에서 생성한 썸네일 (base64)

  BlobUploadCompleteEvent({
    required this.blobId,
    required this.filename,
    required this.pylonPath,
    required this.conversationId,
    this.thumbnailBase64,
  });
}

/// 다운로드 완료 이벤트
class BlobDownloadCompleteEvent {
  final String blobId;
  final String filename;
  final Uint8List bytes;

  BlobDownloadCompleteEvent({
    required this.blobId,
    required this.filename,
    required this.bytes,
  });
}

typedef ProgressCallback = void Function(String blobId, int processed, int total);
typedef UploadCompleteCallback = void Function(String blobId, String pylonPath);
typedef DownloadCompleteCallback = void Function(String blobId, String filename, Uint8List bytes);
typedef ErrorCallback = void Function(String blobId, String error);

class BlobTransferService {
  static const int chunkSize = 65536; // 64KB

  /// 데스크탑에서 Pylon 원본 직접 접근 (sameDevice 최적화)
  /// TODO: 테스트 완료 후 true로 변경
  static const bool enableSameDeviceOptimization = false;

  final RelayService _relayService;
  final _uuid = const Uuid();

  final Map<String, BlobTransfer> _transfers = {};
  final _progressController = StreamController<BlobTransfer>.broadcast();
  final _uploadCompleteController = StreamController<BlobUploadCompleteEvent>.broadcast();
  final _downloadCompleteController = StreamController<BlobDownloadCompleteEvent>.broadcast();
  StreamSubscription? _messageSubscription;

  Stream<BlobTransfer> get progressStream => _progressController.stream;
  Stream<BlobUploadCompleteEvent> get uploadCompleteStream => _uploadCompleteController.stream;
  Stream<BlobDownloadCompleteEvent> get downloadCompleteStream => _downloadCompleteController.stream;

  // 콜백
  ProgressCallback? onProgress;
  UploadCompleteCallback? onUploadComplete;
  DownloadCompleteCallback? onDownloadComplete;
  ErrorCallback? onError;

  BlobTransferService(this._relayService) {
    _listenToMessages();
  }

  /// 디버그 로그를 콘솔과 Pylon 모두에 출력
  void _log(String tag, String message, [Map<String, dynamic>? extra]) {
    print('[$tag] $message ${extra ?? ''}');
    _relayService.sendDebugLog(tag, message, extra);
  }

  /// 파일명 정규화 (Pylon과 동일한 방식)
  /// 영숫자, 점, 밑줄, 하이픈만 허용하고 나머지는 밑줄로 교체
  String _sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  void _listenToMessages() {
    _messageSubscription = _relayService.messageStream.listen((data) {
      final type = data['type'] as String?;

      switch (type) {
        case 'blob_start':
          _handleBlobStart(data);
          break;
        case 'blob_chunk':
          _handleBlobChunk(data);
          break;
        case 'blob_end':
          _handleBlobEnd(data);
          break;
        case 'blob_ack':
          _handleBlobAck(data);
          break;
        case 'blob_upload_complete':
          _handleBlobUploadComplete(data);
          break;
      }
    });
  }

  // ============ 업로드 (Client → Pylon) ============

  /// 이미지 업로드 시작 (바이트 기반 - 모든 플랫폼 호환)
  /// 반환: blobId (진행 추적용)
  Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String filename,
    required int targetDeviceId,
    required String workspaceId,
    required String conversationId,
    String? message,
    String? mimeType,
    bool sameDevice = false,
  }) async {
    try {
      final mime = mimeType ?? lookupMimeType(filename) ?? 'application/octet-stream';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Pylon과 동일한 방식으로 파일명 정규화 (특수문자 → _)
      final safeFilename = _sanitizeFilename('${timestamp}_$filename');

      _log('BLOB', 'Starting upload: $safeFilename (${bytes.length} bytes) to device $targetDeviceId');

      // 캐시에 저장 (업로드한 이미지는 바로 캐시)
      imageCache.put(safeFilename, bytes);

      final blobId = _uuid.v4();
      final totalChunks = (bytes.length / chunkSize).ceil();

      final transfer = BlobTransfer(
        blobId: blobId,
        filename: safeFilename,
        mimeType: mime,
        totalSize: bytes.length,
        chunkSize: chunkSize,
        totalChunks: totalChunks,
        context: {
          'type': 'image_upload',
          'workspaceId': workspaceId,
          'conversationId': conversationId,
          'message': message,
        },
        isUpload: true,
      );
      transfer.bytes = bytes;
      transfer.state = BlobTransferState.uploading;
      _transfers[blobId] = transfer;

      // sameDevice 최적화 (데스크탑에서 Pylon과 같은 머신일 때)
      final useSameDevice = sameDevice && enableSameDeviceOptimization;

      // blob_start 전송
      _log('BLOB', 'Sending blob_start', {
        'targetDeviceId': targetDeviceId,
        'blobId': blobId,
        'totalChunks': totalChunks,
        'sameDevice': useSameDevice,
        'fileSize': bytes.length,
      });

      _relayService.send({
        'type': 'blob_start',
        'to': {'deviceId': targetDeviceId, 'deviceType': 'pylon'},
        'payload': {
          'blobId': blobId,
          'filename': safeFilename,
          'mimeType': mime,
          'totalSize': bytes.length,
          'chunkSize': chunkSize,
          'totalChunks': totalChunks,
          'encoding': 'base64',
          'context': transfer.context,
          'sameDevice': useSameDevice,
          'localPath': null,  // 캐시 기반이므로 로컬 경로 없음
        },
      });

      _progressController.add(transfer);

      // 동일 디바이스 최적화가 활성화된 경우 청크 전송 스킵
      if (useSameDevice) {
        _relayService.send({
          'type': 'blob_end',
          'to': {'deviceId': targetDeviceId, 'deviceType': 'pylon'},
          'payload': {
            'blobId': blobId,
            'checksum': _calculateChecksum(bytes),
            'totalReceived': bytes.length,
            'skipped': true,
          },
        });
        transfer.state = BlobTransferState.waitingAck;
      } else {
        // 청크 전송
        await _sendChunks(blobId, bytes, targetDeviceId);
      }

      return blobId;
    } catch (e, stack) {
      _log('BLOB', 'Upload error: $e\nStack: $stack');
      onError?.call('', e.toString());
      return null;
    }
  }

  Future<void> _sendChunks(String blobId, Uint8List bytes, int targetDeviceId) async {
    final transfer = _transfers[blobId];
    if (transfer == null) return;

    _log('BLOB', 'Starting to send ${transfer.totalChunks} chunks', {'blobId': blobId});

    for (int i = 0; i < transfer.totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize > bytes.length) ? bytes.length : start + chunkSize;
      final chunk = bytes.sublist(start, end);

      _relayService.send({
        'type': 'blob_chunk',
        'to': {'deviceId': targetDeviceId, 'deviceType': 'pylon'},
        'payload': {
          'blobId': blobId,
          'index': i,
          'data': base64Encode(chunk),
          'size': chunk.length,
        },
      });

      transfer.processedChunks = i + 1;
      _progressController.add(transfer);
      onProgress?.call(blobId, transfer.processedChunks, transfer.totalChunks);

      // 너무 빠른 전송 방지
      await Future.delayed(const Duration(milliseconds: 5));
    }

    _log('BLOB', 'All chunks sent, sending blob_end', {'blobId': blobId});

    // blob_end 전송
    _relayService.send({
      'type': 'blob_end',
      'to': {'deviceId': targetDeviceId, 'deviceType': 'pylon'},
      'payload': {
        'blobId': blobId,
        'checksum': _calculateChecksum(bytes),
        'totalReceived': bytes.length,
      },
    });

    transfer.state = BlobTransferState.waitingAck;
    _progressController.add(transfer);
  }

  String _calculateChecksum(Uint8List bytes) {
    return 'sha256:${sha256.convert(bytes).toString()}';
  }

  /// Pylon에서 업로드 완료 응답 처리
  void _handleBlobUploadComplete(Map<String, dynamic> data) {
    final payload = data['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final blobId = payload['blobId'] as String;
    final pylonPath = payload['path'] as String;
    final conversationId = payload['conversationId'] as String? ?? '';
    final thumbnailBase64 = payload['thumbnail'] as String?;

    final transfer = _transfers[blobId];
    if (transfer != null) {
      transfer.state = BlobTransferState.completed;
      transfer.pylonPath = pylonPath;
      _progressController.add(transfer);

      // 썸네일이 있으면 캐시에 저장 (썸네일 키: thumb_filename)
      if (thumbnailBase64 != null && thumbnailBase64.isNotEmpty) {
        final thumbBytes = base64Decode(thumbnailBase64);
        imageCache.put('thumb_${transfer.filename}', thumbBytes);
        _log('BLOB', 'Thumbnail cached: thumb_${transfer.filename}');
      }

      // 완료 이벤트 발송
      _uploadCompleteController.add(BlobUploadCompleteEvent(
        blobId: blobId,
        filename: transfer.filename,
        pylonPath: pylonPath,
        conversationId: conversationId,
        thumbnailBase64: thumbnailBase64,
      ));

      onUploadComplete?.call(blobId, pylonPath);

      _log('BLOB', 'Upload complete', {
        'blobId': blobId,
        'filename': transfer.filename,
        'pylonPath': pylonPath,
        'hasThumbnail': thumbnailBase64 != null,
      });
    }
  }

  // ============ 다운로드 (Pylon → Client) ============

  /// 이미지 다운로드 요청
  void requestImage({
    required int targetDeviceId,
    required String conversationId,
    required String filename,
  }) {
    // 캐시에 있으면 바로 반환
    final cached = imageCache.get(filename);
    if (cached != null) {
      _log('BLOB', 'Cache hit: $filename');
      _downloadCompleteController.add(BlobDownloadCompleteEvent(
        blobId: 'cached_$filename',
        filename: filename,
        bytes: cached,
      ));
      onDownloadComplete?.call('cached_$filename', filename, cached);
      return;
    }

    // 캐시에 없으면 Pylon에서 다운로드
    final blobId = _uuid.v4();
    _log('BLOB', 'Requesting download: $filename', {'blobId': blobId});

    _relayService.send({
      'type': 'blob_request',
      'to': {'deviceId': targetDeviceId, 'deviceType': 'pylon'},
      'payload': {
        'blobId': blobId,
        'conversationId': conversationId,
        'filename': filename,
      },
    });
  }

  /// Pylon에서 다운로드 시작 응답 처리
  void _handleBlobStart(Map<String, dynamic> data) {
    final payload = data['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final blobId = payload['blobId'] as String;
    final filename = payload['filename'] as String;

    // 이미 캐시에 있으면 스킵
    if (imageCache.contains(filename)) {
      _log('BLOB', 'Already cached, skipping download: $filename');
      return;
    }

    final transfer = BlobTransfer(
      blobId: blobId,
      filename: filename,
      mimeType: payload['mimeType'] as String,
      totalSize: payload['totalSize'] as int,
      chunkSize: payload['chunkSize'] as int,
      totalChunks: payload['totalChunks'] as int,
      context: payload['context'] as Map<String, dynamic>? ?? {},
      isUpload: false,
    );

    transfer.state = BlobTransferState.downloading;
    transfer.chunks = List.filled(transfer.totalChunks, Uint8List(0));
    _transfers[blobId] = transfer;
    _progressController.add(transfer);

    _log('BLOB', 'Download started: $filename', {
      'blobId': blobId,
      'totalChunks': transfer.totalChunks,
      'totalSize': transfer.totalSize,
    });
  }

  /// 청크 수신 처리
  void _handleBlobChunk(Map<String, dynamic> data) {
    final payload = data['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final blobId = payload['blobId'] as String;
    final transfer = _transfers[blobId];
    if (transfer == null) return;

    final index = payload['index'] as int;
    final dataStr = payload['data'] as String;
    final chunk = base64Decode(dataStr);

    transfer.chunks[index] = chunk;
    transfer.processedChunks++;
    _progressController.add(transfer);
    onProgress?.call(blobId, transfer.processedChunks, transfer.totalChunks);
  }

  /// 다운로드 완료 처리
  Future<void> _handleBlobEnd(Map<String, dynamic> data) async {
    final payload = data['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final blobId = payload['blobId'] as String;
    final transfer = _transfers[blobId];
    if (transfer == null || transfer.isUpload) return;

    // 모든 청크 조합
    final allBytes = BytesBuilder();
    for (final chunk in transfer.chunks) {
      allBytes.add(chunk);
    }
    final bytes = allBytes.toBytes();

    // 캐시에 저장
    imageCache.put(transfer.filename, bytes);

    transfer.bytes = bytes;
    transfer.state = BlobTransferState.completed;
    _progressController.add(transfer);

    // 메모리 정리
    transfer.chunks.clear();

    // 완료 이벤트 발송
    _downloadCompleteController.add(BlobDownloadCompleteEvent(
      blobId: blobId,
      filename: transfer.filename,
      bytes: bytes,
    ));

    onDownloadComplete?.call(blobId, transfer.filename, bytes);

    _log('BLOB', 'Download complete: ${transfer.filename}', {
      'blobId': blobId,
      'size': bytes.length,
    });
  }

  void _handleBlobAck(Map<String, dynamic> data) {
    // 필요시 재전송 로직
  }

  // ============ 캐시 관리 ============

  /// 캐시에서 이미지 가져오기
  Uint8List? getCachedImage(String filename) {
    return imageCache.get(filename);
  }

  /// 캐시에 이미지가 있는지 확인
  bool hasCachedImage(String filename) {
    return imageCache.contains(filename);
  }

  /// 캐시 상태 정보
  Map<String, dynamic> get cacheStats => imageCache.stats;

  // ============ 기타 ============

  BlobTransfer? getTransfer(String blobId) => _transfers[blobId];

  void cancelTransfer(String blobId) {
    final transfer = _transfers[blobId];
    if (transfer != null) {
      transfer.state = BlobTransferState.failed;
      transfer.error = 'Cancelled';
      _progressController.add(transfer);
    }
  }

  void removeTransfer(String blobId) {
    _transfers.remove(blobId);
  }

  void dispose() {
    _messageSubscription?.cancel();
    _progressController.close();
    _uploadCompleteController.close();
    _downloadCompleteController.close();
  }
}
