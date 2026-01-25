import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/pending_request.dart';
import '../../../state/providers/claude_provider.dart';
import '../../../state/providers/workspace_provider.dart';
import '../../../state/providers/relay_provider.dart';
import 'permission_request_view.dart';
import 'question_request_view.dart';

class RequestBar extends ConsumerWidget {
  const RequestBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRequest = ref.watch(currentRequestProvider);
    final pendingCount = ref.watch(pendingRequestsProvider).length;

    if (currentRequest == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: NordColors.nord1,
        border: Border(
          top: BorderSide(color: NordColors.nord2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switch (currentRequest) {
            PermissionRequest() => PermissionRequestView(
                request: currentRequest,
                onRespond: (decision) => _respondPermission(ref, currentRequest, decision),
              ),
            QuestionRequest() => QuestionRequestView(
                request: currentRequest,
                onSelectAnswer: (qIdx, answer) {
                  ref.read(pendingRequestsProvider.notifier)
                      .updateQuestionAnswer(qIdx, answer);
                },
                onSubmit: (answer) => _respondQuestion(ref, currentRequest, answer),
              ),
          },

          // Pending count
          if (pendingCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  '+${pendingCount - 1} more',
                  style: const TextStyle(
                    fontSize: 11,
                    color: NordColors.nord3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _respondPermission(WidgetRef ref, PermissionRequest request, String decision) {
    final selectedItem = ref.read(selectedItemProvider);
    if (selectedItem == null || !selectedItem.isConversation) return;

    // Record response
    final decisionText = decision == 'allow' ? '승인됨' : '거부됨';
    ref.read(claudeMessagesProvider.notifier)
        .addUserResponse('permission', '${request.toolName} ($decisionText)');

    // Send to relay (workspace 기반)
    ref.read(relayServiceProvider).sendClaudePermission(
      selectedItem.deviceId,
      selectedItem.workspaceId,
      selectedItem.itemId, // conversationId
      request.toolUseId,
      decision,
    );

    // Remove from queue (상태는 Pylon 이벤트로 관리)
    ref.read(pendingRequestsProvider.notifier).removeFirst();
  }

  void _respondQuestion(WidgetRef ref, QuestionRequest request, dynamic answer) {
    final selectedItem = ref.read(selectedItemProvider);
    if (selectedItem == null || !selectedItem.isConversation) return;

    // Record response
    final answerText = answer is List ? answer.join(', ') : answer.toString();
    ref.read(claudeMessagesProvider.notifier)
        .addUserResponse('question', answerText);

    // Send to relay (workspace 기반)
    ref.read(relayServiceProvider).sendClaudeAnswer(
      selectedItem.deviceId,
      selectedItem.workspaceId,
      selectedItem.itemId, // conversationId
      request.toolUseId,
      answer,
    );

    // Remove from queue (상태는 Pylon 이벤트로 관리)
    ref.read(pendingRequestsProvider.notifier).removeFirst();
  }
}
