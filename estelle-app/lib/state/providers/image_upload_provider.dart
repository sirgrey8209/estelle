import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 업로드 중인 이미지 상태
enum ImageUploadStatus {
  uploading,
  completed,
  failed,
}

/// 업로드 이미지 정보
class UploadingImage {
  final String blobId;
  final String localPath;
  final String filename;
  final int totalChunks;
  final String conversationId;
  final String? message; // 함께 보낸 메시지

  int sentChunks = 0;
  ImageUploadStatus status = ImageUploadStatus.uploading;
  String? pylonPath; // Pylon에서 저장된 경로
  String? error;

  UploadingImage({
    required this.blobId,
    required this.localPath,
    required this.filename,
    required this.totalChunks,
    required this.conversationId,
    this.message,
  });

  double get progress => totalChunks > 0 ? sentChunks / totalChunks : 0;
  bool get isCompleted => status == ImageUploadStatus.completed;
  bool get isFailed => status == ImageUploadStatus.failed;
}

/// 대기 중인 메시지
class QueuedMessage {
  final String text;
  final DateTime queuedAt;

  QueuedMessage({required this.text, required this.queuedAt});
}

/// 이미지 업로드 상태 관리
class ImageUploadState {
  final Map<String, UploadingImage> uploads; // blobId -> UploadingImage
  final List<String> recentImagePaths; // 최근 완료된 이미지 경로들 (Pylon 경로)
  final List<QueuedMessage> messageQueue; // 대기 중인 메시지
  final String? currentConversationId;

  const ImageUploadState({
    this.uploads = const {},
    this.recentImagePaths = const [],
    this.messageQueue = const [],
    this.currentConversationId,
  });

  bool get hasActiveUpload => uploads.values.any((u) => u.status == ImageUploadStatus.uploading);
  bool get hasQueuedMessages => messageQueue.isNotEmpty;
  bool get isBusy => hasActiveUpload || hasQueuedMessages;

  /// 현재 대화의 업로드 중인 이미지들
  List<UploadingImage> getUploadsForConversation(String conversationId) {
    return uploads.values.where((u) => u.conversationId == conversationId).toList();
  }

  ImageUploadState copyWith({
    Map<String, UploadingImage>? uploads,
    List<String>? recentImagePaths,
    List<QueuedMessage>? messageQueue,
    String? currentConversationId,
  }) {
    return ImageUploadState(
      uploads: uploads ?? this.uploads,
      recentImagePaths: recentImagePaths ?? this.recentImagePaths,
      messageQueue: messageQueue ?? this.messageQueue,
      currentConversationId: currentConversationId ?? this.currentConversationId,
    );
  }
}

class ImageUploadNotifier extends StateNotifier<ImageUploadState> {
  ImageUploadNotifier() : super(const ImageUploadState());

  /// 업로드 시작
  void startUpload({
    required String blobId,
    required String localPath,
    required String filename,
    required int totalChunks,
    required String conversationId,
    String? message,
  }) {
    final upload = UploadingImage(
      blobId: blobId,
      localPath: localPath,
      filename: filename,
      totalChunks: totalChunks,
      conversationId: conversationId,
      message: message,
    );

    state = state.copyWith(
      uploads: {...state.uploads, blobId: upload},
      currentConversationId: conversationId,
    );
  }

  /// 진행률 업데이트
  void updateProgress(String blobId, int sentChunks) {
    final upload = state.uploads[blobId];
    if (upload == null) return;

    upload.sentChunks = sentChunks;
    state = state.copyWith(uploads: {...state.uploads});
  }

  /// 업로드 완료
  void completeUpload(String blobId, String pylonPath) {
    final upload = state.uploads[blobId];
    if (upload == null) return;

    upload.status = ImageUploadStatus.completed;
    upload.pylonPath = pylonPath;

    // 최근 이미지 경로에 추가
    final newRecentPaths = [...state.recentImagePaths, pylonPath];

    state = state.copyWith(
      uploads: {...state.uploads},
      recentImagePaths: newRecentPaths,
    );
  }

  /// 업로드 실패
  void failUpload(String blobId, String error) {
    final upload = state.uploads[blobId];
    if (upload == null) return;

    upload.status = ImageUploadStatus.failed;
    upload.error = error;
    state = state.copyWith(uploads: {...state.uploads});
  }

  /// 실패한 업로드 제거
  void removeUpload(String blobId) {
    final newUploads = Map<String, UploadingImage>.from(state.uploads);
    newUploads.remove(blobId);
    state = state.copyWith(uploads: newUploads);
  }

  /// 메시지 큐에 추가
  void queueMessage(String text) {
    final queued = QueuedMessage(text: text, queuedAt: DateTime.now());
    state = state.copyWith(messageQueue: [...state.messageQueue, queued]);
  }

  /// 큐에서 메시지 꺼내기
  QueuedMessage? dequeueMessage() {
    if (state.messageQueue.isEmpty) return null;

    final first = state.messageQueue.first;
    state = state.copyWith(messageQueue: state.messageQueue.sublist(1));
    return first;
  }

  /// 최근 이미지 경로들 소비 (메시지에 포함 후)
  List<String> consumeRecentImagePaths() {
    final paths = List<String>.from(state.recentImagePaths);
    state = state.copyWith(recentImagePaths: []);
    return paths;
  }

  /// 대화 변경 시 상태 초기화
  void onConversationChange(String conversationId) {
    // 다른 대화로 넘어가면 최근 이미지 경로 초기화
    if (state.currentConversationId != conversationId) {
      state = state.copyWith(
        recentImagePaths: [],
        currentConversationId: conversationId,
      );
    }
  }

  /// 완료된 업로드 정리
  void cleanupCompleted() {
    final newUploads = Map<String, UploadingImage>.from(state.uploads);
    newUploads.removeWhere((_, u) => u.isCompleted);
    state = state.copyWith(uploads: newUploads);
  }
}

final imageUploadProvider = StateNotifierProvider<ImageUploadNotifier, ImageUploadState>((ref) {
  return ImageUploadNotifier();
});

/// 현재 업로드 중 여부
final isUploadingProvider = Provider<bool>((ref) {
  return ref.watch(imageUploadProvider).hasActiveUpload;
});

/// 메시지 전송 가능 여부 (업로드 중이거나 큐가 있으면 false)
final canSendMessageProvider = Provider<bool>((ref) {
  return !ref.watch(imageUploadProvider).isBusy;
});
