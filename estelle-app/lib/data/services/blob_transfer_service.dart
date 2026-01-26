import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'relay_service.dart';

/// Blob 전송 상태
enum BlobTransferState {
  pending,
  uploading,
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
  int sentChunks = 0;
  List<Uint8List> chunks = [];
  String? localPath;
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

  double get progress => totalChunks > 0 ? sentChunks / totalChunks : 0;
}

/// 업로드 완료 이벤트
class BlobUploadCompleteEvent {
  final String blobId;
  final String pylonPath;
  final String conversationId;

  BlobUploadCompleteEvent({
    required this.blobId,
    required this.pylonPath,
    required this.conversationId,
  });
}

typedef ProgressCallback = void Function(String blobId, int sent, int total);
typedef CompleteCallback = void Function(String blobId, String pylonPath);
typedef ErrorCallback = void Function(String blobId, String error);

class BlobTransferService {
  static const int chunkSize = 65536; // 64KB
  final RelayService _relayService;
  final _uuid = const Uuid();

  final Map<String, BlobTransfer> _transfers = {};
  final _progressController = StreamController<BlobTransfer>.broadcast();
  final _completeController = StreamController<BlobUploadCompleteEvent>.broadcast();
  StreamSubscription? _messageSubscription;

  Stream<BlobTransfer> get progressStream => _progressController.stream;
  Stream<BlobUploadCompleteEvent> get completeStream => _completeController.stream;

  String? _imagesDir;

  // 콜백
  ProgressCallback? onProgress;
  CompleteCallback? onComplete;
  ErrorCallback? onError;

  BlobTransferService(this._relayService) {
    _initializeDirectories();
    _listenToMessages();
  }

  /// 디버그 로그를 콘솔과 Pylon 모두에 출력
  void _log(String tag, String message, [Map<String, dynamic>? extra]) {
    print('[$tag] $message ${extra ?? ''}');
    _relayService.sendDebugLog(tag, message, extra);
  }

  Future<void> _initializeDirectories() async {
    final appDir = await getApplicationDocumentsDirectory();
    _imagesDir = path.join(appDir.path, 'estelle', 'images');

    final dir = Directory(_imagesDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
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

  /// 이미지 파일 업로드 시작
  /// 반환: blobId (진행 추적용)
  Future<String?> uploadImage({
    required File file,
    required int targetDeviceId,
    required String deskId,
    required String conversationId,
    String? message,
    bool sameDevice = false,
  }) async {
    try {
      // 디렉토리 초기화 대기
      if (_imagesDir == null) {
        _log('BLOB', 'Waiting for directory initialization...');
        await _initializeDirectories();
      }

      if (_imagesDir == null) {
        _log('BLOB', 'ERROR: Images directory not initialized');
        return null;
      }

      final bytes = await file.readAsBytes();
      final filename = path.basename(file.path);
      final mimeType = lookupMimeType(filename) ?? 'application/octet-stream';

      _log('BLOB', 'Starting upload: $filename (${bytes.length} bytes) to device $targetDeviceId');

      // 로컬 이미지 폴더에 복사
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final localFilename = '${timestamp}_$filename';
      final localPath = path.join(_imagesDir!, localFilename);

      await file.copy(localPath);

      final blobId = _uuid.v4();
      final totalChunks = (bytes.length / chunkSize).ceil();

      final transfer = BlobTransfer(
        blobId: blobId,
        filename: filename,
        mimeType: mimeType,
        totalSize: bytes.length,
        chunkSize: chunkSize,
        totalChunks: totalChunks,
        context: {
          'type': 'image_upload',
          'deskId': deskId,
          'conversationId': conversationId,
          'message': message,
        },
        isUpload: true,
      );
      transfer.localPath = localPath;
      transfer.state = BlobTransferState.uploading;
      _transfers[blobId] = transfer;

      // blob_start 전송
      _log('BLOB', 'Sending blob_start', {
        'targetDeviceId': targetDeviceId,
        'blobId': blobId,
        'totalChunks': totalChunks,
        'sameDevice': sameDevice,
        'fileSize': bytes.length,
      });
      _relayService.send({
        'type': 'blob_start',
        'to': {'deviceId': targetDeviceId, 'deviceType': 'pylon'},
        'payload': {
          'blobId': blobId,
          'filename': localFilename,  // 타임스탬프 포함된 파일명 전달
          'mimeType': mimeType,
          'totalSize': bytes.length,
          'chunkSize': chunkSize,
          'totalChunks': totalChunks,
          'encoding': 'base64',
          'context': transfer.context,
          'sameDevice': sameDevice,
          'localPath': sameDevice ? localPath : null,
        },
      });

      _progressController.add(transfer);

      // 동일 디바이스면 청크 전송 스킵
      if (sameDevice) {
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

      transfer.sentChunks = i + 1;
      _progressController.add(transfer);
      onProgress?.call(blobId, transfer.sentChunks, transfer.totalChunks);

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

    final transfer = _transfers[blobId];
    if (transfer != null) {
      transfer.state = BlobTransferState.completed;
      transfer.pylonPath = pylonPath;
      _progressController.add(transfer);
    }

    // 완료 이벤트 발송
    _completeController.add(BlobUploadCompleteEvent(
      blobId: blobId,
      pylonPath: pylonPath,
      conversationId: conversationId,
    ));

    onComplete?.call(blobId, pylonPath);
  }

  // ============ 다운로드 (Pylon → Client) ============

  void _handleBlobStart(Map<String, dynamic> data) {
    final payload = data['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final blobId = payload['blobId'] as String;
    final transfer = BlobTransfer(
      blobId: blobId,
      filename: payload['filename'] as String,
      mimeType: payload['mimeType'] as String,
      totalSize: payload['totalSize'] as int,
      chunkSize: payload['chunkSize'] as int,
      totalChunks: payload['totalChunks'] as int,
      context: payload['context'] as Map<String, dynamic>? ?? {},
      isUpload: false,
    );

    transfer.state = BlobTransferState.uploading;
    transfer.chunks = List.filled(transfer.totalChunks, Uint8List(0));
    _transfers[blobId] = transfer;
    _progressController.add(transfer);
  }

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
    transfer.sentChunks++;
    _progressController.add(transfer);
  }

  Future<void> _handleBlobEnd(Map<String, dynamic> data) async {
    final payload = data['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final blobId = payload['blobId'] as String;
    final transfer = _transfers[blobId];
    if (transfer == null || transfer.isUpload) return;

    // 다운로드인 경우에만 처리
    final allBytes = BytesBuilder();
    for (final chunk in transfer.chunks) {
      allBytes.add(chunk);
    }
    final bytes = allBytes.toBytes();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final localFilename = '${timestamp}_${transfer.filename}';
    final localPath = path.join(_imagesDir!, localFilename);

    final file = File(localPath);
    await file.writeAsBytes(bytes);

    transfer.localPath = localPath;
    transfer.state = BlobTransferState.completed;
    _progressController.add(transfer);

    transfer.chunks.clear();
  }

  void _handleBlobAck(Map<String, dynamic> data) {
    // 필요시 재전송 로직
  }

  /// 특정 이미지 요청 (Pylon에서 다운로드)
  void requestImage({
    required int targetDeviceId,
    required String blobId,
    required String filename,
    String? remotePath,
  }) {
    _relayService.send({
      'type': 'blob_request',
      'to': {'deviceId': targetDeviceId, 'deviceType': 'pylon'},
      'payload': {
        'blobId': blobId,
        'filename': filename,
        'localPath': remotePath,
      },
    });
  }

  /// 이미지가 로컬에 있는지 확인
  Future<String?> getLocalImagePath(String filename) async {
    if (_imagesDir == null) await _initializeDirectories();

    final dir = Directory(_imagesDir!);
    if (!await dir.exists()) return null;

    await for (final entity in dir.list()) {
      if (entity is File && path.basename(entity.path).endsWith(filename)) {
        return entity.path;
      }
    }
    return null;
  }

  String? get imagesDirectory => _imagesDir;

  BlobTransfer? getTransfer(String blobId) => _transfers[blobId];

  void cancelUpload(String blobId) {
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
    _completeController.close();
  }
}
