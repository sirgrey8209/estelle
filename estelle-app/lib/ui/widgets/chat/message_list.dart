import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/claude_message.dart';
import '../../../state/providers/claude_provider.dart';
import '../../../state/providers/image_upload_provider.dart';
import '../../../state/providers/workspace_provider.dart';
import '../../../state/providers/file_download_provider.dart';
import 'message_bubble.dart';
import 'tool_card.dart';
import 'result_info.dart';
import 'streaming_bubble.dart';
import 'working_indicator.dart';
import 'uploading_image_bubble.dart';
import '../viewers/file_viewer_dialog.dart';

class MessageList extends ConsumerStatefulWidget {
  const MessageList({super.key});

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final _scrollController = ScrollController();
  bool _showScrollButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    // reverse: true이므로 maxScrollExtent 근처 = 오래된 메시지 영역 (화면 상단)
    // 히스토리 로드 트리거
    if (position.pixels >= position.maxScrollExtent - 100) {
      ref.read(claudeMessagesProvider.notifier).loadMoreHistory();
    }

    // 스크롤 버튼 표시 여부 (offset 0 = 맨 아래, pixels > 200이면 버튼 표시)
    final shouldShow = position.pixels > 200;
    if (shouldShow != _showScrollButton) {
      setState(() {
        _showScrollButton = shouldShow;
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    // reverse: true이므로 offset 0 = 맨 아래
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(claudeMessagesProvider);
    final textBuffer = ref.watch(currentTextBufferProvider);
    final workStartTime = ref.watch(workStartTimeProvider);
    final sendingMessage = ref.watch(sendingMessageProvider);
    final isLoadingHistory = ref.watch(isLoadingHistoryProvider);
    final hasMoreHistory = ref.watch(hasMoreHistoryProvider);

    final claudeState = ref.watch(claudeStateProvider);

    // 현재 대화의 업로드 중인 이미지들
    final uploadState = ref.watch(imageUploadProvider);
    final selectedItem = ref.watch(selectedItemProvider);
    final currentConversationId = selectedItem?.itemId ?? '';
    final uploadingImages = uploadState.getUploadsForConversation(currentConversationId)
        .where((u) => u.status == ImageUploadStatus.uploading)
        .toList();

    if (messages.isEmpty && textBuffer.isEmpty) {
      // 초기 로드 중이면 로딩 인디케이터 표시
      if (isLoadingHistory) {
        return Container(
          color: NordColors.nord0,
          child: const Center(
            child: CircularProgressIndicator(
              color: NordColors.nord9,
            ),
          ),
        );
      }

      // 대화 초기화 중 (working 상태)
      if (claudeState == 'working') {
        return Container(
          color: NordColors.nord0,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NordColors.nord8,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '대화를 시작하는 중...',
                  style: TextStyle(
                    color: NordColors.nord4,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        color: NordColors.nord0,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '세션이 없습니다.',
                style: TextStyle(
                  color: NordColors.nord4,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '메시지를 입력하시면 자동으로 새 세션이 시작됩니다.',
                style: TextStyle(
                  color: NordColors.nord3,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 로딩 인디케이터 표시 여부 (리스트 끝 = reverse 시 화면 상단)
    final showLoadingIndicator = isLoadingHistory || hasMoreHistory;

    // 아이템 카운트 계산
    // reverse: true이므로 최신 아이템이 index 0
    // 순서: [working] [streaming] [uploading images] [sending] [messages...] [loading indicator]
    final hasWorking = workStartTime != null;
    final hasStreaming = textBuffer.isNotEmpty;
    final hasSending = sendingMessage != null;
    final hasUploading = uploadingImages.isNotEmpty;

    final itemCount = (hasWorking ? 1 : 0) +
        (hasStreaming ? 1 : 0) +
        (hasUploading ? uploadingImages.length : 0) +
        (hasSending ? 1 : 0) +
        messages.length +
        (showLoadingIndicator ? 1 : 0);

    return Stack(
      children: [
        Container(
          color: NordColors.nord0,
          child: ListView.builder(
            controller: _scrollController,
            reverse: true, // 핵심: 아래에서 위로 렌더링
            cacheExtent: 500,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              int currentIdx = 0;

              // 1. Working indicator (index 0) - 가장 아래 (최신)
              if (hasWorking) {
                if (index == currentIdx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: WorkingIndicator(startTime: workStartTime),
                  );
                }
                currentIdx++;
              }

              // 2. Streaming bubble
              if (hasStreaming) {
                if (index == currentIdx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: StreamingBubble(content: textBuffer),
                  );
                }
                currentIdx++;
              }

              // 3. Uploading images
              if (hasUploading) {
                final uploadStartIdx = currentIdx;
                final uploadEndIdx = uploadStartIdx + uploadingImages.length;
                if (index >= uploadStartIdx && index < uploadEndIdx) {
                  final uploadIdx = index - uploadStartIdx;
                  final upload = uploadingImages[uploadIdx];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: UploadingImageBubble(upload: upload),
                  );
                }
                currentIdx += uploadingImages.length;
              }

              // 4. Sending placeholder
              if (hasSending) {
                if (index == currentIdx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: MessageBubble.sending(content: sendingMessage),
                  );
                }
                currentIdx++;
              }

              // 5. Messages (역순: 최신이 먼저)
              final messageStartIdx = currentIdx;
              final messageEndIdx = messageStartIdx + messages.length;
              if (index >= messageStartIdx && index < messageEndIdx) {
                // 역순 인덱스: index가 작을수록 최신 메시지
                final msgIndex = messages.length - 1 - (index - messageStartIdx);
                final message = messages[msgIndex];
                return RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: switch (message) {
                      UserTextMessage msg => MessageBubble.user(
                        content: msg.content,
                        attachments: msg.attachments,
                      ),
                      AssistantTextMessage msg => MessageBubble.assistant(content: msg.content),
                      ToolCallMessage msg => ToolCard(message: msg),
                      ResultInfoMessage msg => ResultInfo(message: msg),
                      ErrorMessage msg => MessageBubble.error(error: msg.error),
                      UserResponseMessage msg => MessageBubble.response(
                        responseType: msg.responseType,
                        content: msg.content,
                      ),
                      FileAttachmentMessage msg => _FileAttachmentBubble(message: msg),
                    },
                  ),
                );
              }

              // 6. Loading indicator (맨 끝 = reverse 시 화면 상단)
              if (showLoadingIndicator && index == itemCount - 1) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: isLoadingHistory
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: NordColors.nord3,
                            ),
                          )
                        : const Text(
                            '↑ 스크롤하여 이전 메시지 로드',
                            style: TextStyle(
                              fontSize: 12,
                              color: NordColors.nord3,
                            ),
                          ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
        // Scroll to bottom button
        if (_showScrollButton)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: NordColors.nord2,
              foregroundColor: NordColors.nord4,
              elevation: 2,
              child: const Icon(Icons.keyboard_arrow_down, size: 24),
            ),
          ),
      ],
    );
  }
}

/// 파일 첨부 메시지 버블 (다운로드 상태 관리 포함)
class _FileAttachmentBubble extends ConsumerWidget {
  final FileAttachmentMessage message;

  const _FileAttachmentBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(fileDownloadStateProvider(message.file.filename));
    final selectedItem = ref.watch(selectedItemProvider);

    return MessageBubble.fileAttachment(
      file: message.file,
      downloadState: downloadState,
      onDownload: () {
        if (selectedItem == null) return;

        // 다운로드 시작
        ref.read(fileDownloadProvider.notifier).startDownload(
          filename: message.file.filename,
          targetDeviceId: selectedItem.deviceId,
          conversationId: selectedItem.itemId,
          filePath: message.file.path,
        );
      },
      onOpen: () {
        // 뷰어 열기
        showFileViewer(context, ref, message.file);
      },
    );
  }
}
