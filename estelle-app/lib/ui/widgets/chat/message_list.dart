import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/claude_message.dart';
import '../../../state/providers/claude_provider.dart';
import 'message_bubble.dart';
import 'tool_card.dart';
import 'result_info.dart';
import 'streaming_bubble.dart';
import 'working_indicator.dart';

class MessageList extends ConsumerStatefulWidget {
  const MessageList({super.key});

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final _scrollController = ScrollController();
  bool _isNearBottom = true;
  double? _scrollOffsetBeforePrepend;
  int _lastMessageCount = 0;

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

    // 상단 근처에 도달하면 더 많은 히스토리 로드
    if (position.pixels <= 100) {
      _scrollOffsetBeforePrepend = position.pixels;
      ref.read(claudeMessagesProvider.notifier).loadMoreHistory();
    }

    // 하단 근처 여부 체크 (자동 스크롤용)
    _isNearBottom = position.pixels >= position.maxScrollExtent - 100;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && _isNearBottom) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(claudeMessagesProvider);
    final textBuffer = ref.watch(currentTextBufferProvider);
    final workStartTime = ref.watch(workStartTimeProvider);
    final sendingMessage = ref.watch(sendingMessageProvider);
    final isLoadingHistory = ref.watch(isLoadingHistoryProvider);
    final hasMoreHistory = ref.watch(hasMoreHistoryProvider);

    // Listen for prepended messages to adjust scroll
    ref.listen<int>(prependedCountProvider, (previous, next) {
      if (next > 0 && _scrollController.hasClients) {
        // 스크롤 위치 조정: prepend된 메시지 높이만큼 아래로 이동
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            // 대략적인 메시지 높이 (평균 60px로 가정)
            final addedHeight = next * 60.0;
            final newOffset = (_scrollOffsetBeforePrepend ?? 0) + addedHeight;
            _scrollController.jumpTo(newOffset.clamp(0, _scrollController.position.maxScrollExtent));
            _scrollOffsetBeforePrepend = null;
          }
          // Reset prepended count
          ref.read(prependedCountProvider.notifier).state = 0;
        });
      }
    });

    // Auto scroll only when new messages are added (not on every rebuild)
    final currentCount = messages.length + (textBuffer.isNotEmpty ? 1 : 0);
    if (currentCount > _lastMessageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    _lastMessageCount = currentCount;

    if (messages.isEmpty && textBuffer.isEmpty) {
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

    // 로딩 인디케이터 표시 여부 (상단)
    final showLoadingIndicator = isLoadingHistory || hasMoreHistory;

    return Container(
      color: NordColors.nord0,
      child: ListView.builder(
        controller: _scrollController,
        cacheExtent: 500, // Pre-render 500px above/below viewport
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: (showLoadingIndicator ? 1 : 0) +
            messages.length +
            (sendingMessage != null ? 1 : 0) +
            (textBuffer.isNotEmpty ? 1 : 0) +
            (workStartTime != null ? 1 : 0),
        itemBuilder: (context, index) {
          // Loading indicator at top
          if (showLoadingIndicator && index == 0) {
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

          // Adjust index for messages
          final msgIndex = showLoadingIndicator ? index - 1 : index;

          // Messages
          if (msgIndex >= 0 && msgIndex < messages.length) {
            final message = messages[msgIndex];
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: switch (message) {
                  UserTextMessage msg => MessageBubble.user(content: msg.content),
                  AssistantTextMessage msg => MessageBubble.assistant(content: msg.content),
                  ToolCallMessage msg => ToolCard(message: msg),
                  ResultInfoMessage msg => ResultInfo(message: msg),
                  ErrorMessage msg => MessageBubble.error(error: msg.error),
                  UserResponseMessage msg => MessageBubble.response(
                    responseType: msg.responseType,
                    content: msg.content,
                  ),
                },
              ),
            );
          }

          // Sending message placeholder (전송 중...)
          final sendingIdx = (showLoadingIndicator ? 1 : 0) + messages.length;
          if (sendingMessage != null && index == sendingIdx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: MessageBubble.sending(content: sendingMessage),
            );
          }

          // Streaming text buffer
          final streamIdx = sendingIdx + (sendingMessage != null ? 1 : 0);
          if (textBuffer.isNotEmpty && index == streamIdx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: StreamingBubble(content: textBuffer),
            );
          }

          // Working indicator
          if (workStartTime != null) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: WorkingIndicator(startTime: workStartTime),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
