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
  inProgress,
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
  final bool isUpload; // true: 업로드, false: 다운로드

  BlobTransferState state = BlobTransferState.pending;
  int receivedChunks = 0;
  List<Uint8List> chunks = [];
  String? localPath;
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

  double get progress => totalChunks > 0 ? receivedChunks / totalChunks : 0;
}

typedef BlobProgressCallback = void Function(String blobId, double progress);
typedef BlobCompleteCallback = void Function(String blobId, String? localPath, String? error);

class BlobTransferService {
  static const int chunkSize = 65536; // 64KB
  final RelayService _relayService;
  final _uuid = const Uuid();

  final Map<String, BlobTransfer> _transfers = {};
  final _progressController = StreamController<BlobTransfer>.broadcast();
  StreamSubscription? _messageSubscription;

  Stream<BlobTransfer> get progressStream => _progressController.stream;

  String? _imagesDir;

  BlobTransferService(this._relayService) {
    _initializeDirectories();
    _listenToMessages();
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
      }
    });
  }

  /// 이미지 파일 업로드 시작
  Future<String?> uploadImage({
    required File file,
    required int targetDeviceId,
    required String deskId,
    required String conversationId,
    String? message,
    bool sameDevice = false,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final filename = path.basename(file.path);
      final mimeType = lookupMimeType(filename) ?? 'application/octet-stream';

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
      transfer.state = BlobTransferState.inProgress;
      _transfers[blobId] = transfer;

      // blob_start 전송
      _relayService.send({
        'type': 'blob_start',
        'to': {'deviceId': targetDeviceId, 'deviceType': 'pylon'},
        'payload': {
          'blobId': blobId,
          'filename': filename,
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

      // 동일 디바이스면 청크 전송 스킵
      if (sameDevice) {
        // blob_end만 전송
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

        transfer.state = BlobTransferState.completed;
        _progressController.add(transfer);
      } else {
        // 청크 전송
        await _sendChunks(blobId, bytes, targetDeviceId);
      }

      return localPath;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  Future<void> _sendChunks(String blobId, Uint8List bytes, int targetDeviceId) async {
    final transfer = _transfers[blobId];
    if (transfer == null) return;

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

      transfer.receivedChunks = i + 1;
      _progressController.add(transfer);

      // 너무 빠른 전송 방지
      await Future.delayed(const Duration(milliseconds: 10));
    }

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

    transfer.state = BlobTransferState.completed;
    _progressController.add(transfer);
  }

  String _calculateChecksum(Uint8List bytes) {
    return 'sha256:${sha256.convert(bytes).toString()}';
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

    transfer.state = BlobTransferState.inProgress;
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
    transfer.receivedChunks++;
    _progressController.add(transfer);
  }

  Future<void> _handleBlobEnd(Map<String, dynamic> data) async {
    final payload = data['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final blobId = payload['blobId'] as String;
    final transfer = _transfers[blobId];
    if (transfer == null) return;

    // 모든 청크 조합
    final allBytes = BytesBuilder();
    for (final chunk in transfer.chunks) {
      allBytes.add(chunk);
    }
    final bytes = allBytes.toBytes();

    // 로컬에 저장
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final localFilename = '${timestamp}_${transfer.filename}';
    final localPath = path.join(_imagesDir!, localFilename);

    final file = File(localPath);
    await file.writeAsBytes(bytes);

    transfer.localPath = localPath;
    transfer.state = BlobTransferState.completed;
    _progressController.add(transfer);

    // 청크 메모리 해제
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

  /// 이미지 폴더 경로
  String? get imagesDirectory => _imagesDir;

  BlobTransfer? getTransfer(String blobId) => _transfers[blobId];

  void dispose() {
    _messageSubscription?.cancel();
    _progressController.close();
  }
}
