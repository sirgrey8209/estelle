import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/workspace_info.dart';
import '../../../state/providers/workspace_provider.dart';
import '../../../state/providers/claude_provider.dart';
import '../../../state/providers/relay_provider.dart';
import 'message_list.dart';
import 'input_bar.dart';
import '../requests/request_bar.dart';

class ChatArea extends ConsumerWidget {
  final bool showHeader;

  const ChatArea({super.key, this.showHeader = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedItem = ref.watch(selectedItemProvider);
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider);
    final selectedConversation = ref.watch(selectedConversationProvider);

    if (selectedItem == null || selectedWorkspace == null) {
      return const _NoItemSelected();
    }

    // 대화가 선택된 경우만 채팅 표시
    if (!selectedItem.isConversation) {
      return const _NoItemSelected();
    }

    return Column(
      children: [
        if (showHeader) _ChatHeader(
          workspace: selectedWorkspace,
          conversation: selectedConversation,
        ),
        const Expanded(child: MessageList()),
        const _BottomArea(),
      ],
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  final WorkspaceInfo workspace;
  final ConversationInfo? conversation;

  const _ChatHeader({required this.workspace, this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claudeState = ref.watch(claudeStateProvider);

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
                      _ConversationStatusDot(conversation: conversation!),
                    ],
                  ),
                Text(
                  '📁 ${workspace.workingDir}',
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

/// 퍼미션 모드 Provider (글로벌)
final permissionModeProvider = StateProvider<String>((ref) => 'default');

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
    final currentMode = ref.read(permissionModeProvider);
    final currentIndex = _permissionModes.indexOf(currentMode);
    final nextIndex = (currentIndex + 1) % _permissionModes.length;
    final nextMode = _permissionModes[nextIndex];

    ref.read(permissionModeProvider.notifier).state = nextMode;
    ref.read(relayServiceProvider).setPermissionMode(nextMode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(permissionModeProvider);

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

class _StateBadge extends StatelessWidget {
  final String state;

  const _StateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    switch (state) {
      case 'working':
        textColor = NordColors.nord13;
        break;
      case 'permission':
        textColor = NordColors.nord12;
        break;
      default:
        textColor = NordColors.nord3;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: NordColors.nord2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        state,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
        ),
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

/// 대화 상태 표시 점 (working/waiting 상태일 때 점멸)
class _ConversationStatusDot extends StatefulWidget {
  final ConversationInfo conversation;

  const _ConversationStatusDot({required this.conversation});

  @override
  State<_ConversationStatusDot> createState() => _ConversationStatusDotState();
}

class _ConversationStatusDotState extends State<_ConversationStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  String get _status {
    if (widget.conversation.hasError) return 'error';
    if (widget.conversation.isWorking || widget.conversation.isWaiting) return 'working';
    if (widget.conversation.unread) return 'unread';
    return 'idle';
  }

  bool get _shouldBlink => _status == 'working';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(_ConversationStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.status != widget.conversation.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (_shouldBlink) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    if (color == null) return const SizedBox.shrink();

    if (_shouldBlink) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(_animation.value),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color? _getColor() {
    switch (_status) {
      case 'error':
        return AppColors.statusError;
      case 'working':
        return AppColors.statusWorking;
      case 'unread':
        return AppColors.statusSuccess;
      default:
        return null;
    }
  }
}
