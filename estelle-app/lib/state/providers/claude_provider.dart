import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/claude_message.dart';
import '../../data/models/desk_info.dart';
import '../../data/models/pending_request.dart';
import '../../data/services/relay_service.dart';
import 'relay_provider.dart';
import 'desk_provider.dart';

/// Claude state (idle, working, permission)
final claudeStateProvider = StateProvider<String>((ref) => 'idle');

/// Is thinking (shows thinking indicator)
final isThinkingProvider = StateProvider<bool>((ref) => false);

/// Current text buffer (streaming)
final currentTextBufferProvider = StateProvider<String>((ref) => '');

/// Work start time for elapsed timer
final workStartTimeProvider = StateProvider<DateTime?>((ref) => null);

/// Sending message placeholder (null when not sending)
final sendingMessageProvider = StateProvider<String?>((ref) => null);

/// History pagination state
final isLoadingHistoryProvider = StateProvider<bool>((ref) => false);
final hasMoreHistoryProvider = StateProvider<bool>((ref) => true);
final historyOffsetProvider = StateProvider<int>((ref) => 0);

/// Prepended message count (for scroll position adjustment)
final prependedCountProvider = StateProvider<int>((ref) => 0);

/// Claude messages notifier
class ClaudeMessagesNotifier extends StateNotifier<List<ClaudeMessage>> {
  final RelayService _relay;
  final Ref _ref;
  final Map<String, List<ClaudeMessage>> _deskMessagesCache = {};
  final Map<String, List<PendingRequest>> _deskRequestsCache = {};

  ClaudeMessagesNotifier(this._relay, this._ref) : super([]) {
    _relay.messageStream.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    // desk_sync_result 처리
    if (type == 'desk_sync_result') {
      _handleDeskSyncResult(data['payload'] as Map<String, dynamic>?);
      return;
    }

    // history_result 처리 (페이징)
    if (type == 'history_result') {
      _handleHistoryResult(data['payload'] as Map<String, dynamic>?);
      return;
    }

    if (type != 'claude_event') return;

    final payload = data['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final deskId = payload['deskId'] as String?;
    final event = payload['event'] as Map<String, dynamic>?;
    if (deskId == null || event == null) return;

    final selectedDesk = _ref.read(selectedDeskProvider);
    if (selectedDesk?.deskId == deskId) {
      _handleClaudeEvent(event);
    } else {
      _saveEventForDesk(deskId, event);
    }
  }

  void _handleDeskSyncResult(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final deskId = payload['deskId'] as String?;
    final messagesRaw = payload['messages'] as List<dynamic>?;
    final pendingEvent = payload['pendingEvent'] as Map<String, dynamic>?;

    if (deskId == null) return;

    final selectedDesk = _ref.read(selectedDeskProvider);
    if (selectedDesk?.deskId != deskId) return;

    // 메시지 히스토리 복원
    if (messagesRaw != null) {
      final messages = _parseMessages(messagesRaw);
      state = messages;
      // Set initial offset for pagination
      _ref.read(historyOffsetProvider.notifier).state = messages.length;
      _ref.read(hasMoreHistoryProvider.notifier).state = messages.length >= 50;
    }

    // pending 이벤트 복원
    if (pendingEvent != null) {
      _handleClaudeEvent(pendingEvent);
    }

    _ref.read(currentTextBufferProvider.notifier).state = '';
  }

  void _handleHistoryResult(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final deskId = payload['deskId'] as String?;
    final messagesRaw = payload['messages'] as List<dynamic>?;
    final hasMore = payload['hasMore'] as bool? ?? false;
    final offset = payload['offset'] as int? ?? 0;

    if (deskId == null) return;

    final selectedDesk = _ref.read(selectedDeskProvider);
    if (selectedDesk?.deskId != deskId) return;

    _ref.read(isLoadingHistoryProvider.notifier).state = false;
    _ref.read(hasMoreHistoryProvider.notifier).state = hasMore;

    if (messagesRaw != null && messagesRaw.isNotEmpty) {
      final olderMessages = _parseMessages(messagesRaw);
      // Prepend older messages
      state = [...olderMessages, ...state];
      _ref.read(historyOffsetProvider.notifier).state = offset + messagesRaw.length;
      // Notify for scroll adjustment
      _ref.read(prependedCountProvider.notifier).state = olderMessages.length;
    }
  }

  /// 더 많은 히스토리 로드 요청
  void loadMoreHistory() {
    final selectedDesk = _ref.read(selectedDeskProvider);
    if (selectedDesk == null) return;

    final isLoading = _ref.read(isLoadingHistoryProvider);
    final hasMore = _ref.read(hasMoreHistoryProvider);
    if (isLoading || !hasMore) return;

    _ref.read(isLoadingHistoryProvider.notifier).state = true;
    final offset = _ref.read(historyOffsetProvider);

    _relay.requestHistory(
      selectedDesk.deviceId,
      selectedDesk.deskId,
      limit: 50,
      offset: offset,
    );
  }

  List<ClaudeMessage> _parseMessages(List<dynamic> messagesRaw) {
    final List<ClaudeMessage> messages = [];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final msg in messagesRaw) {
      if (msg is! Map<String, dynamic>) continue;

      final role = msg['role'] as String?;
      final msgType = msg['type'] as String?;
      final timestamp = (msg['timestamp'] as num?)?.toInt() ?? now;
      final id = '$timestamp-${messages.length}';

      if (role == 'user' && msgType == 'text') {
        messages.add(UserTextMessage(
          id: id,
          content: msg['content'] as String? ?? '',
          timestamp: timestamp,
        ));
      } else if (role == 'assistant' && msgType == 'text') {
        messages.add(AssistantTextMessage(
          id: id,
          content: msg['content'] as String? ?? '',
          timestamp: timestamp,
        ));
      } else if (msgType == 'tool_start' || msgType == 'tool_complete') {
        messages.add(ToolCallMessage(
          id: id,
          toolName: msg['toolName'] as String? ?? '',
          toolInput: (msg['toolInput'] as Map<String, dynamic>?) ?? {},
          isComplete: msgType == 'tool_complete',
          success: msg['success'] as bool?,
          output: msg['output'] as String?,
          error: msg['error'] as String?,
          timestamp: timestamp,
        ));
      } else if (msgType == 'error') {
        messages.add(ErrorMessage(
          id: id,
          error: msg['content'] as String? ?? '',
          timestamp: timestamp,
        ));
      } else if (msgType == 'result') {
        final usage = msg['usage'] as Map<String, dynamic>?;
        messages.add(ResultInfoMessage(
          id: id,
          durationMs: (msg['duration_ms'] as num?)?.toInt() ?? 0,
          inputTokens: (usage?['inputTokens'] as num?)?.toInt() ?? 0,
          outputTokens: (usage?['outputTokens'] as num?)?.toInt() ?? 0,
          cacheReadTokens: (usage?['cacheReadInputTokens'] as num?)?.toInt() ?? 0,
          timestamp: timestamp,
        ));
      }
    }

    return messages;
  }

  void _handleClaudeEvent(Map<String, dynamic> event) {
    final eventType = event['type'] as String?;
    if (eventType == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    switch (eventType) {
      case 'userMessage':
        // Pylon에서 브로드캐스트된 유저 메시지 (single source of truth)
        _ref.read(sendingMessageProvider.notifier).state = null; // placeholder 제거
        final content = event['content'] as String? ?? '';
        final timestamp = (event['timestamp'] as num?)?.toInt() ?? now;
        state = [
          ...state,
          UserTextMessage(
            id: '$timestamp-user',
            content: content,
            timestamp: timestamp,
          ),
        ];
        break;

      case 'text':
        final content = event['content'] as String? ?? '';
        _ref.read(currentTextBufferProvider.notifier).state += content;
        break;

      case 'textComplete':
        _ref.read(currentTextBufferProvider.notifier).state = '';
        final text = event['text'] as String?;
        if (text != null) {
          state = [
            ...state,
            AssistantTextMessage(
              id: '$now',
              content: text,
              timestamp: now,
            ),
          ];
        }
        break;

      case 'stateUpdate':
        final stateData = event['state'] as Map<String, dynamic>?;
        final stateType = stateData?['type'] as String?;
        _ref.read(isThinkingProvider.notifier).state = stateType == 'thinking';
        break;

      case 'toolInfo':
        _flushTextBuffer();
        final toolName = event['toolName'] as String? ?? '';
        final toolInput = (event['input'] as Map<String, dynamic>?) ?? {};
        state = [
          ...state,
          ToolCallMessage(
            id: '$now-$toolName',
            toolName: toolName,
            toolInput: toolInput,
            isComplete: false,
            timestamp: now,
          ),
        ];
        break;

      case 'toolComplete':
        final toolName = event['toolName'] as String? ?? '';
        final success = event['success'] as bool? ?? true;
        final result = event['result'] as String?;
        final error = event['error'] as String?;

        state = state.map((msg) {
          if (msg is ToolCallMessage && msg.toolName == toolName && !msg.isComplete) {
            return msg.copyWith(
              isComplete: true,
              success: success,
              output: result,
              error: error,
            );
          }
          return msg;
        }).toList();
        break;

      case 'permission_request':
        _flushTextBuffer();
        final toolName = event['toolName'] as String? ?? '';
        final toolInput = (event['toolInput'] as Map<String, dynamic>?) ?? {};
        final toolUseId = event['toolUseId'] as String? ?? '';

        _ref.read(pendingRequestsProvider.notifier).add(
          PermissionRequest(
            toolUseId: toolUseId,
            toolName: toolName,
            toolInput: toolInput,
          ),
        );
        _ref.read(claudeStateProvider.notifier).state = 'permission';
        break;

      case 'askQuestion':
        _flushTextBuffer();
        final questionsRaw = event['questions'] as List<dynamic>? ?? [];
        final toolUseId = event['toolUseId'] as String? ?? '';

        final questions = questionsRaw.map((q) {
          final qMap = q as Map<String, dynamic>;
          final optionsRaw = qMap['options'] as List<dynamic>?;
          return QuestionItem(
            question: qMap['question'] as String? ?? '',
            header: qMap['header'] as String? ?? 'Question',
            options: optionsRaw?.map((o) {
              if (o is Map<String, dynamic>) {
                return o['label'] as String? ?? '';
              }
              return o.toString();
            }).toList() ?? [],
            multiSelect: qMap['multiSelect'] as bool? ?? false,
          );
        }).toList();

        if (questions.isNotEmpty) {
          _ref.read(pendingRequestsProvider.notifier).add(
            QuestionRequest(
              toolUseId: toolUseId,
              questions: questions,
            ),
          );
          _ref.read(claudeStateProvider.notifier).state = 'permission';
        }
        break;

      case 'state':
        final stateValue = event['state'] as String? ?? 'idle';
        _ref.read(claudeStateProvider.notifier).state = stateValue;
        if (stateValue == 'idle') {
          _flushTextBuffer();
          _ref.read(isThinkingProvider.notifier).state = false;
        }
        break;

      case 'result':
        _flushTextBuffer();
        final durationMs = (event['duration_ms'] as num?)?.toInt() ?? 0;
        final usage = event['usage'] as Map<String, dynamic>?;
        final inputTokens = (usage?['inputTokens'] as num?)?.toInt() ?? 0;
        final outputTokens = (usage?['outputTokens'] as num?)?.toInt() ?? 0;
        final cacheReadTokens = (usage?['cacheReadInputTokens'] as num?)?.toInt() ?? 0;

        state = [
          ...state,
          ResultInfoMessage(
            id: '$now-result',
            durationMs: durationMs,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            timestamp: now,
          ),
        ];
        _ref.read(workStartTimeProvider.notifier).state = null;
        _ref.read(isThinkingProvider.notifier).state = false;
        break;

      case 'error':
        _flushTextBuffer();
        final error = event['error'] as String? ?? 'Unknown error';
        _ref.read(claudeStateProvider.notifier).state = 'idle';
        _ref.read(isThinkingProvider.notifier).state = false;
        state = [
          ...state,
          ErrorMessage(
            id: '$now-error',
            error: error,
            timestamp: now,
          ),
        ];
        break;
    }
  }

  void _saveEventForDesk(String deskId, Map<String, dynamic> event) {
    final eventType = event['type'] as String?;
    final now = DateTime.now().millisecondsSinceEpoch;

    switch (eventType) {
      case 'userMessage':
        final content = event['content'] as String? ?? '';
        final timestamp = (event['timestamp'] as num?)?.toInt() ?? now;
        final saved = _deskMessagesCache[deskId]?.toList() ?? [];
        saved.add(UserTextMessage(
          id: '$timestamp-user',
          content: content,
          timestamp: timestamp,
        ));
        _deskMessagesCache[deskId] = saved;
        break;

      case 'textComplete':
        final text = event['text'] as String?;
        if (text != null) {
          final saved = _deskMessagesCache[deskId]?.toList() ?? [];
          saved.add(AssistantTextMessage(
            id: '$now',
            content: text,
            timestamp: now,
          ));
          _deskMessagesCache[deskId] = saved;
        }
        break;

      case 'result':
        final usage = event['usage'] as Map<String, dynamic>?;
        final saved = _deskMessagesCache[deskId]?.toList() ?? [];
        saved.add(ResultInfoMessage(
          id: '$now-result',
          durationMs: (event['duration_ms'] as num?)?.toInt() ?? 0,
          inputTokens: (usage?['inputTokens'] as num?)?.toInt() ?? 0,
          outputTokens: (usage?['outputTokens'] as num?)?.toInt() ?? 0,
          cacheReadTokens: (usage?['cacheReadInputTokens'] as num?)?.toInt() ?? 0,
          timestamp: now,
        ));
        _deskMessagesCache[deskId] = saved;
        break;

      case 'error':
        final error = event['error'] as String? ?? 'Unknown error';
        final saved = _deskMessagesCache[deskId]?.toList() ?? [];
        saved.add(ErrorMessage(
          id: '$now-error',
          error: error,
          timestamp: now,
        ));
        _deskMessagesCache[deskId] = saved;
        break;

      case 'permission_request':
      case 'askQuestion':
        final savedRequests = _deskRequestsCache[deskId]?.toList() ?? [];
        if (eventType == 'permission_request') {
          savedRequests.add(PermissionRequest(
            toolUseId: event['toolUseId'] as String? ?? '',
            toolName: event['toolName'] as String? ?? '',
            toolInput: (event['toolInput'] as Map<String, dynamic>?) ?? {},
          ));
        }
        _deskRequestsCache[deskId] = savedRequests;
        break;
    }
  }

  void _flushTextBuffer() {
    final buffer = _ref.read(currentTextBufferProvider);
    if (buffer.trim().isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      state = [
        ...state,
        AssistantTextMessage(
          id: '$now-buffer',
          content: buffer.trim(),
          timestamp: now,
        ),
      ];
      _ref.read(currentTextBufferProvider.notifier).state = '';
    }
  }

  void addUserMessage(String content) {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = [
      ...state,
      UserTextMessage(
        id: '$now-user',
        content: content,
        timestamp: now,
      ),
    ];
  }

  void addUserResponse(String responseType, String content) {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = [
      ...state,
      UserResponseMessage(
        id: '$now-response',
        responseType: responseType,
        content: content,
        timestamp: now,
      ),
    ];
  }

  void saveCurrentDesk(String deskId) {
    _deskMessagesCache[deskId] = state.toList();
    final requests = _ref.read(pendingRequestsProvider);
    if (requests.isNotEmpty) {
      _deskRequestsCache[deskId] = requests.toList();
    } else {
      _deskRequestsCache.remove(deskId);
    }
  }

  void loadDesk(String deskId) {
    state = _deskMessagesCache[deskId] ?? [];
    final requests = _deskRequestsCache[deskId] ?? [];
    _ref.read(pendingRequestsProvider.notifier).replaceAll(requests);
    _ref.read(currentTextBufferProvider.notifier).state = '';
    _ref.read(claudeStateProvider.notifier).state = requests.isNotEmpty ? 'permission' : 'idle';
    _ref.read(isThinkingProvider.notifier).state = false;
    _ref.read(workStartTimeProvider.notifier).state = null;
    // Reset pagination state
    _ref.read(isLoadingHistoryProvider.notifier).state = false;
    _ref.read(hasMoreHistoryProvider.notifier).state = true;
    _ref.read(historyOffsetProvider.notifier).state = 0;
  }

  void clearMessages() {
    state = [];
    _ref.read(currentTextBufferProvider.notifier).state = '';
    _ref.read(pendingRequestsProvider.notifier).clear();
    _ref.read(claudeStateProvider.notifier).state = 'idle';
    _ref.read(isThinkingProvider.notifier).state = false;
    _ref.read(workStartTimeProvider.notifier).state = null;
  }

  void clearDeskCache(String deskId) {
    _deskMessagesCache.remove(deskId);
    _deskRequestsCache.remove(deskId);
  }

  /// 데스크 선택 시 호출 - 현재 데스크 저장 + 새 데스크 로드 + sync 요청
  void onDeskSelected(DeskInfo? oldDesk, DeskInfo newDesk) {
    // 이전 데스크 저장
    if (oldDesk != null) {
      saveCurrentDesk(oldDesk.deskId);
    }

    // 새 데스크 로드 (캐시된 메시지가 있으면)
    loadDesk(newDesk.deskId);

    // Pylon에 데스크 선택 알림 + sync 요청
    _relay.selectDesk(newDesk.deviceId, newDesk.deskId);

    // 마지막 선택 데스크 저장
    PylonDesksNotifier.saveLastDesk(newDesk.deviceId, newDesk.deskId);
  }
}

final claudeMessagesProvider = StateNotifierProvider<ClaudeMessagesNotifier, List<ClaudeMessage>>((ref) {
  final relay = ref.watch(relayServiceProvider);
  return ClaudeMessagesNotifier(relay, ref);
});

/// Pending requests notifier
class PendingRequestsNotifier extends StateNotifier<List<PendingRequest>> {
  PendingRequestsNotifier() : super([]);

  void add(PendingRequest request) {
    state = [...state, request];
  }

  void removeFirst() {
    if (state.isNotEmpty) {
      state = state.sublist(1);
    }
  }

  void replaceAll(List<PendingRequest> requests) {
    state = requests;
  }

  void clear() {
    state = [];
  }

  void updateQuestionAnswer(int questionIndex, String answer) {
    if (state.isEmpty) return;
    final first = state.first;
    if (first is! QuestionRequest) return;

    final newAnswers = Map<int, String>.from(first.answers);
    newAnswers[questionIndex] = answer;
    state = [
      first.copyWith(answers: newAnswers),
      ...state.sublist(1),
    ];
  }
}

final pendingRequestsProvider = StateNotifierProvider<PendingRequestsNotifier, List<PendingRequest>>((ref) {
  return PendingRequestsNotifier();
});

/// Current request (first in queue)
final currentRequestProvider = Provider<PendingRequest?>((ref) {
  final requests = ref.watch(pendingRequestsProvider);
  return requests.isEmpty ? null : requests.first;
});
