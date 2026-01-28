import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/claude_message.dart';
import '../../data/models/pending_request.dart';
import '../../data/services/relay_service.dart';
import '../../data/services/image_cache_service.dart' as cache;
import 'relay_provider.dart';
import 'workspace_provider.dart';

/// JSON에서 List를 안전하게 추출
List<dynamic>? _safeList(dynamic value) {
  if (value == null) return null;
  if (value is List) return value;
  debugPrint('[WARN] Expected List but got ${value.runtimeType}');
  return null;
}

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
  final Map<String, List<ClaudeMessage>> _conversationMessagesCache = {};
  final Map<String, List<PendingRequest>> _conversationRequestsCache = {};

  ClaudeMessagesNotifier(this._relay, this._ref) : super([]) {
    _relay.messageStream.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    // conversation_sync_result 처리
    if (type == 'conversation_sync_result') {
      _handleConversationSyncResult(data['payload'] as Map<String, dynamic>?);
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

    final conversationId = payload['conversationId'] as String?;
    final event = payload['event'] as Map<String, dynamic>?;
    if (conversationId == null || event == null) return;

    final selectedItem = _ref.read(selectedItemProvider);
    if (selectedItem != null && selectedItem.isConversation && selectedItem.itemId == conversationId) {
      _handleClaudeEvent(event);
    } else {
      _saveEventForConversation(conversationId, event);
    }
  }

  void _handleConversationSyncResult(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final deviceId = payload['deviceId'] as int?;
    final conversationId = payload['conversationId'] as String?;
    final messagesRaw = _safeList(payload['messages']);
    final totalCount = payload['totalCount'] as int? ?? 0;
    final pendingEvent = payload['pendingEvent'] as Map<String, dynamic>?;

    if (conversationId == null) return;

    final selectedItem = _ref.read(selectedItemProvider);
    if (selectedItem == null || !selectedItem.isConversation || selectedItem.itemId != conversationId) return;

    // 메시지가 비어있고 totalCount > 0이면 history_request로 받아야 함
    if ((messagesRaw == null || messagesRaw.isEmpty) && totalCount > 0 && deviceId != null) {
      _relay.requestHistory(deviceId, selectedItem.workspaceId, conversationId, limit: 50, offset: 0);
      _ref.read(hasMoreHistoryProvider.notifier).state = totalCount > 50;
      return;
    }

    // 메시지 히스토리 복원
    if (messagesRaw != null && messagesRaw.isNotEmpty) {
      final messages = _parseMessages(messagesRaw);
      state = messages;
      _ref.read(historyOffsetProvider.notifier).state = messages.length;
      _ref.read(hasMoreHistoryProvider.notifier).state = messages.length >= 50;
    }

    // pending 이벤트 복원
    if (pendingEvent != null) {
      _handleClaudeEvent(pendingEvent);
    }

    // 상태 복원
    final hasActiveSession = payload['hasActiveSession'] as bool? ?? false;
    if (hasActiveSession) {
      _ref.read(claudeStateProvider.notifier).state = 'working';
      _ref.read(isThinkingProvider.notifier).state = true;
      // 타이머 복원 (정확한 시작 시간은 모르므로 현재 시간으로 설정)
      if (_ref.read(workStartTimeProvider) == null) {
        _ref.read(workStartTimeProvider.notifier).state = DateTime.now();
      }
    } else if (pendingEvent != null) {
      _ref.read(claudeStateProvider.notifier).state = 'permission';
    } else {
      _ref.read(claudeStateProvider.notifier).state = 'idle';
      _ref.read(isThinkingProvider.notifier).state = false;
    }

    _ref.read(currentTextBufferProvider.notifier).state = '';
  }

  void _handleHistoryResult(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final conversationId = payload['conversationId'] as String?;
    final messagesRaw = _safeList(payload['messages']);
    final hasMore = payload['hasMore'] as bool? ?? false;
    final offset = payload['offset'] as int? ?? 0;
    final hasActiveSession = payload['hasActiveSession'] as bool? ?? false;
    final workStartTime = payload['workStartTime'] as int?;

    if (conversationId == null) return;

    final selectedItem = _ref.read(selectedItemProvider);
    if (selectedItem == null || !selectedItem.isConversation || selectedItem.itemId != conversationId) return;

    _ref.read(isLoadingHistoryProvider.notifier).state = false;
    _ref.read(hasMoreHistoryProvider.notifier).state = hasMore;

    if (messagesRaw != null && messagesRaw.isNotEmpty) {
      final messages = _parseMessages(messagesRaw);

      if (offset == 0) {
        // 초기 로드: 메시지 교체 (대화 전환 시 캐시된 메시지도 교체)
        state = messages;

        // 활성 세션 상태 복원
        if (hasActiveSession) {
          _ref.read(claudeStateProvider.notifier).state = 'working';
          _ref.read(isThinkingProvider.notifier).state = true;
          // 타이머 시작 시간 복원
          if (workStartTime != null) {
            _ref.read(workStartTimeProvider.notifier).state =
                DateTime.fromMillisecondsSinceEpoch(workStartTime);
          } else {
            _ref.read(workStartTimeProvider.notifier).state = DateTime.now();
          }
        } else {
          // 작업 완료 상태로 변경 (다른 대화 보는 중 작업 완료된 경우)
          _ref.read(claudeStateProvider.notifier).state = 'idle';
          _ref.read(isThinkingProvider.notifier).state = false;
          _ref.read(workStartTimeProvider.notifier).state = null;
        }
      } else {
        // 더 많은 히스토리 로드: 앞에 추가
        state = [...messages, ...state];
        _ref.read(prependedCountProvider.notifier).state = messages.length;
      }

      _ref.read(historyOffsetProvider.notifier).state = offset + messagesRaw.length;
    }
  }

  /// 더 많은 히스토리 로드 요청
  void loadMoreHistory() {
    final selectedItem = _ref.read(selectedItemProvider);
    if (selectedItem == null || !selectedItem.isConversation) return;

    final isLoading = _ref.read(isLoadingHistoryProvider);
    final hasMore = _ref.read(hasMoreHistoryProvider);
    if (isLoading || !hasMore) return;

    _ref.read(isLoadingHistoryProvider.notifier).state = true;
    final offset = _ref.read(historyOffsetProvider);

    _relay.requestHistory(
      selectedItem.deviceId,
      selectedItem.workspaceId,
      selectedItem.itemId,
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
        final rawContent = msg['content'] as String? ?? '';
        final parsed = UserTextMessage.parseContent(rawContent);
        messages.add(UserTextMessage(
          id: id,
          content: parsed.text,
          attachments: parsed.attachments.isNotEmpty ? parsed.attachments : null,
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
        _ref.read(sendingMessageProvider.notifier).state = null;
        final rawContent = event['content'] as String? ?? '';
        final parsed = UserTextMessage.parseContent(rawContent);
        final timestamp = (event['timestamp'] as num?)?.toInt() ?? now;

        // 썸네일이 있으면 캐시에 저장 (브로드캐스트로 받은 이미지)
        final thumbnail = event['thumbnail'] as String?;
        if (thumbnail != null && thumbnail.isNotEmpty && parsed.attachments.isNotEmpty) {
          try {
            final thumbBytes = base64Decode(thumbnail);
            // 첫 번째 첨부파일의 썸네일로 저장
            cache.imageCache.put('thumb_${parsed.attachments.first.filename}', thumbBytes);
          } catch (e) {
            debugPrint('[THUMBNAIL] Failed to decode: $e');
          }
        }

        state = [
          ...state,
          UserTextMessage(
            id: '$timestamp-user',
            content: parsed.text,
            attachments: parsed.attachments.isNotEmpty ? parsed.attachments : null,
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
        final questionsRaw = _safeList(event['questions']) ?? [];
        final toolUseId = event['toolUseId'] as String? ?? '';

        final questions = questionsRaw.map((q) {
          final qMap = q as Map<String, dynamic>;
          final optionsRaw = _safeList(qMap['options']);
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
        final hasPending = _ref.read(pendingRequestsProvider).isNotEmpty;
        if (hasPending && stateValue != 'permission') {
          _ref.read(claudeStateProvider.notifier).state = 'permission';
        } else {
          _ref.read(claudeStateProvider.notifier).state = stateValue;
        }
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
        final hasPendingOnError = _ref.read(pendingRequestsProvider).isNotEmpty;
        _ref.read(claudeStateProvider.notifier).state = hasPendingOnError ? 'permission' : 'idle';
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

  void _saveEventForConversation(String conversationId, Map<String, dynamic> event) {
    final eventType = event['type'] as String?;
    final now = DateTime.now().millisecondsSinceEpoch;

    switch (eventType) {
      case 'userMessage':
        final rawContent = event['content'] as String? ?? '';
        final parsed = UserTextMessage.parseContent(rawContent);
        final timestamp = (event['timestamp'] as num?)?.toInt() ?? now;
        final saved = _conversationMessagesCache[conversationId]?.toList() ?? [];
        saved.add(UserTextMessage(
          id: '$timestamp-user',
          content: parsed.text,
          attachments: parsed.attachments.isNotEmpty ? parsed.attachments : null,
          timestamp: timestamp,
        ));
        _conversationMessagesCache[conversationId] = saved;
        break;

      case 'textComplete':
        final text = event['text'] as String?;
        if (text != null) {
          final saved = _conversationMessagesCache[conversationId]?.toList() ?? [];
          saved.add(AssistantTextMessage(
            id: '$now',
            content: text,
            timestamp: now,
          ));
          _conversationMessagesCache[conversationId] = saved;
        }
        break;

      case 'result':
        final usage = event['usage'] as Map<String, dynamic>?;
        final saved = _conversationMessagesCache[conversationId]?.toList() ?? [];
        saved.add(ResultInfoMessage(
          id: '$now-result',
          durationMs: (event['duration_ms'] as num?)?.toInt() ?? 0,
          inputTokens: (usage?['inputTokens'] as num?)?.toInt() ?? 0,
          outputTokens: (usage?['outputTokens'] as num?)?.toInt() ?? 0,
          cacheReadTokens: (usage?['cacheReadInputTokens'] as num?)?.toInt() ?? 0,
          timestamp: now,
        ));
        _conversationMessagesCache[conversationId] = saved;
        break;

      case 'error':
        final error = event['error'] as String? ?? 'Unknown error';
        final saved = _conversationMessagesCache[conversationId]?.toList() ?? [];
        saved.add(ErrorMessage(
          id: '$now-error',
          error: error,
          timestamp: now,
        ));
        _conversationMessagesCache[conversationId] = saved;
        break;

      case 'permission_request':
      case 'askQuestion':
        final savedRequests = _conversationRequestsCache[conversationId]?.toList() ?? [];
        if (eventType == 'permission_request') {
          savedRequests.add(PermissionRequest(
            toolUseId: event['toolUseId'] as String? ?? '',
            toolName: event['toolName'] as String? ?? '',
            toolInput: (event['toolInput'] as Map<String, dynamic>?) ?? {},
          ));
        }
        _conversationRequestsCache[conversationId] = savedRequests;
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
    final parsed = UserTextMessage.parseContent(content);
    state = [
      ...state,
      UserTextMessage(
        id: '$now-user',
        content: parsed.text,
        attachments: parsed.attachments.isNotEmpty ? parsed.attachments : null,
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

  /// 현재 대화 저장
  void saveCurrentConversation(String conversationId) {
    _conversationMessagesCache[conversationId] = state.toList();
    final requests = _ref.read(pendingRequestsProvider);
    if (requests.isNotEmpty) {
      _conversationRequestsCache[conversationId] = requests.toList();
    } else {
      _conversationRequestsCache.remove(conversationId);
    }
  }

  /// 대화 로드
  void loadConversation(String conversationId) {
    final cachedMessages = _conversationMessagesCache[conversationId] ?? [];
    state = cachedMessages;
    final requests = _conversationRequestsCache[conversationId] ?? [];
    _ref.read(pendingRequestsProvider.notifier).replaceAll(requests);
    _ref.read(currentTextBufferProvider.notifier).state = '';
    _ref.read(claudeStateProvider.notifier).state = requests.isNotEmpty ? 'permission' : 'idle';
    _ref.read(isThinkingProvider.notifier).state = false;
    _ref.read(workStartTimeProvider.notifier).state = null;
    // Reset pagination state
    // 캐시가 비어있으면 Pylon에서 히스토리 로드 중 (로딩 표시)
    _ref.read(isLoadingHistoryProvider.notifier).state = cachedMessages.isEmpty;
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

  /// 대화 캐시 삭제
  void clearConversationCache(String conversationId) {
    _conversationMessagesCache.remove(conversationId);
    _conversationRequestsCache.remove(conversationId);
  }

  /// 대화 선택 시 호출 - 현재 대화 저장 + 새 대화 로드 + sync 요청
  void onConversationSelected(SelectedItem? oldItem, SelectedItem newItem) {
    // 이전 대화 저장
    if (oldItem != null && oldItem.isConversation) {
      saveCurrentConversation(oldItem.itemId);
    }

    // 새 대화 로드 (캐시된 메시지가 있으면)
    loadConversation(newItem.itemId);

    // Pylon에 대화 선택 알림 + sync 요청
    _relay.selectConversation(newItem.deviceId, newItem.workspaceId, newItem.itemId);

    // 마지막 선택 저장
    PylonWorkspacesNotifier.saveLastWorkspace(
      workspaceId: newItem.workspaceId,
      itemType: 'conversation',
      itemId: newItem.itemId,
    );
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
