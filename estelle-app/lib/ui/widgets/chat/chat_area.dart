import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/workspace_info.dart';
import '../../../state/providers/workspace_provider.dart';
import '../../../state/providers/claude_provider.dart';
import '../../../state/providers/relay_provider.dart';
import 'message_list.dart';
import 'input_bar.dart';
import '../requests/request_bar.dart';
import '../common/status_dot.dart';

class ChatArea extends ConsumerStatefulWidget {
  final bool showHeader;

  const ChatArea({super.key, this.showHeader = true});

  @override
  ConsumerState<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends ConsumerState<ChatArea> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    final selectedItem = ref.watch(selectedItemProvider);
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider);
    final selectedConversation = ref.watch(selectedConversationProvider);

    // finish_work_complete 이벤트 리스닝
    ref.listen<FinishWorkCompleteEvent?>(finishWorkCompleteProvider, (prev, next) {
      if (next != null && !_dialogShown) {
        // 현재 선택된 대화와 일치하는지 확인
        if (selectedConversation?.conversationId == next.conversationId) {
          _dialogShown = true;
          _showFinishDialog(context, selectedWorkspace!, selectedConversation!);
        }
      }
    });

    // finished 상태인 대화 선택 시 다이얼로그 표시
    if (selectedConversation?.status == ConversationStatus.finished && !_dialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && selectedWorkspace != null) {
          _dialogShown = true;
          _showFinishDialog(context, selectedWorkspace, selectedConversation!);
        }
      });
    }

    // 다른 대화로 전환되면 다이얼로그 상태 초기화
    if (selectedConversation?.status != ConversationStatus.finished) {
      _dialogShown = false;
    }

    if (selectedItem == null || selectedWorkspace == null) {
      return const _NoItemSelected();
    }

    // 대화가 선택된 경우만 채팅 표시
    if (!selectedItem.isConversation) {
      return const _NoItemSelected();
    }

    return Column(
      children: [
        if (widget.showHeader) _ChatHeader(
          workspace: selectedWorkspace,
          conversation: selectedConversation,
        ),
        const Expanded(child: MessageList()),
        const _BottomArea(),
      ],
    );
  }

  void _showFinishDialog(BuildContext context, WorkspaceInfo workspace, ConversationInfo conversation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NordColors.nord1,
        title: const Text('작업 완료', style: TextStyle(color: NordColors.nord5)),
        content: const Text(
          '세션을 삭제하시겠습니까?\n삭제하면 대화 내용이 모두 사라집니다.',
          style: TextStyle(color: NordColors.nord4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(relayServiceProvider).sendClaudeControl(
                workspace.deviceId,
                workspace.workspaceId,
                conversation.conversationId,
                'cancel_finish',
              );
              _dialogShown = false;
              ref.read(finishWorkCompleteProvider.notifier).state = null;
              Navigator.pop(dialogContext);
            },
            child: const Text('아니오', style: TextStyle(color: NordColors.nord4)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NordColors.nord11),
            onPressed: () {
              ref.read(relayServiceProvider).deleteConversation(
                workspace.deviceId,
                workspace.workspaceId,
                conversation.conversationId,
              );
              ref.read(claudeMessagesProvider.notifier).clearMessages();
              ref.read(claudeMessagesProvider.notifier).clearConversationCache(conversation.conversationId);
              _dialogShown = false;
              ref.read(finishWorkCompleteProvider.notifier).state = null;
              Navigator.pop(dialogContext);
            },
            child: const Text('예, 삭제'),
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  final WorkspaceInfo workspace;
  final ConversationInfo? conversation;

  const _ChatHeader({required this.workspace, this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: NordColors.nord1,
        border: Border(
          bottom: BorderSide(color: NordColors.nord2),
        ),
      ),
      child: Row(
        children: [
          // Left side: workspace info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (conversation != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '💬 ${conversation!.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: NordColors.nord5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusDot(
                        status: conversation!.dotStatus,
                        margin: const EdgeInsets.only(left: 6),
                      ),
                    ],
                  ),
                Text(
                  workspace.workingDir,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NordColors.nord4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const Spacer(),

          // Right side: session menu button
          _SessionMenuButton(workspace: workspace, conversation: conversation),
        ],
      ),
    );
  }
}

class _SessionMenuButton extends ConsumerWidget {
  final WorkspaceInfo workspace;
  final ConversationInfo? conversation;

  const _SessionMenuButton({required this.workspace, this.conversation});

  static const _permissionModes = ['default', 'acceptEdits', 'bypassPermissions'];
  static const _permissionLabels = {
    'default': 'Default',
    'acceptEdits': 'Accept Edits',
    'bypassPermissions': 'Bypass All',
  };
  static const _permissionIcons = {
    'default': Icons.security,
    'acceptEdits': Icons.edit_note,
    'bypassPermissions': Icons.warning_amber,
  };
  static const _permissionColors = {
    'default': NordColors.nord4,
    'acceptEdits': NordColors.nord8,
    'bypassPermissions': NordColors.nord12,
  };

  void _cyclePermissionMode(WidgetRef ref) {
    if (conversation == null) return;
    final conversationId = conversation!.conversationId;
    final currentMode = ref.read(permissionModeProvider(conversationId));
    final currentIndex = _permissionModes.indexOf(currentMode);
    final nextIndex = (currentIndex + 1) % _permissionModes.length;
    final nextMode = _permissionModes[nextIndex];

    ref.read(permissionModeProvider(conversationId).notifier).state = nextMode;
    ref.read(relayServiceProvider).setPermissionMode(
      workspace.deviceId,
      workspace.workspaceId,
      conversationId,
      nextMode,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationId = conversation?.conversationId ?? '';
    final currentMode = ref.watch(permissionModeProvider(conversationId));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Permission mode cycle button
        Tooltip(
          message: 'Permission: ${_permissionLabels[currentMode]}',
          child: InkWell(
            onTap: () => _cyclePermissionMode(ref),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                _permissionIcons[currentMode],
                color: _permissionColors[currentMode],
                size: 20,
              ),
            ),
          ),
        ),
        // Menu button
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: NordColors.nord5, size: 20),
          color: NordColors.nord2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (value) => _handleMenuAction(context, ref, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'finish_work',
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: NordColors.nord14, size: 18),
                  SizedBox(width: 8),
                  Text('작업완료', style: TextStyle(color: NordColors.nord5)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'new_session',
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, color: NordColors.nord5, size: 18),
                  SizedBox(width: 8),
                  Text('새 세션', style: TextStyle(color: NordColors.nord5)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'compact',
              child: Row(
                children: [
                  Icon(Icons.compress, color: NordColors.nord5, size: 18),
                  SizedBox(width: 8),
                  Text('컴팩트', style: TextStyle(color: NordColors.nord5)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    if (conversation == null) return;

    switch (action) {
      case 'finish_work':
        _startFinishWorkFlow(context, ref);
        break;
      case 'new_session':
        _showNewSessionDialog(context, ref);
        break;
      case 'compact':
        ref.read(relayServiceProvider).sendClaudeControl(
          workspace.deviceId,
          workspace.workspaceId,
          conversation!.conversationId,
          'compact',
        );
        break;
    }
  }

  void _startFinishWorkFlow(BuildContext context, WidgetRef ref) {
    if (conversation == null) return;

    // Pylon에 finish_work 요청 (Pylon이 상태 관리 및 Claude 메시지 전송)
    ref.read(relayServiceProvider).sendClaudeControl(
      workspace.deviceId,
      workspace.workspaceId,
      conversation!.conversationId,
      'finish_work',
    );
  }

  void _showNewSessionDialog(BuildContext context, WidgetRef ref) {
    if (conversation == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NordColors.nord1,
        title: const Text('새 세션', style: TextStyle(color: NordColors.nord5)),
        content: const Text(
          '현재 세션을 종료하고 새 세션을 시작할까요?\n기존 대화 내용은 삭제됩니다.',
          style: TextStyle(color: NordColors.nord4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: NordColors.nord4)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NordColors.nord11),
            onPressed: () {
              ref.read(relayServiceProvider).sendClaudeControl(
                workspace.deviceId,
                workspace.workspaceId,
                conversation!.conversationId,
                'new_session',
              );
              ref.read(claudeMessagesProvider.notifier).clearMessages();
              ref.read(claudeMessagesProvider.notifier).clearConversationCache(conversation!.conversationId);
              Navigator.pop(context);
            },
            child: const Text('새 세션 시작'),
          ),
        ],
      ),
    );
  }
}

class _BottomArea extends ConsumerWidget {
  const _BottomArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRequest = ref.watch(currentRequestProvider);
    final messages = ref.watch(claudeMessagesProvider);
    final claudeState = ref.watch(claudeStateProvider);

    // 권한/질문 요청이 있으면 RequestBar
    if (currentRequest != null) {
      return const RequestBar();
    }

    // 첫 응답 대기 중 (메시지 없고 working 상태) - 입력창 숨김
    if (messages.isEmpty && claudeState == 'working') {
      return const SizedBox.shrink();
    }

    // 그 외에는 InputBar
    return const InputBar();
  }
}

class _NoItemSelected extends StatelessWidget {
  const _NoItemSelected();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '좌측에서 워크스페이스와 대화를 선택하거나 생성해주세요.',
        style: TextStyle(
          fontSize: 16,
          color: NordColors.nord3,
        ),
      ),
    );
  }
}
