import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/desk_info.dart';
import '../../../state/providers/desk_provider.dart';
import '../../../state/providers/claude_provider.dart';
import '../../../state/providers/relay_provider.dart';
import 'message_list.dart';
import 'input_bar.dart';
import '../requests/request_bar.dart';
import '../deploy/deploy_dialog.dart';

class ChatArea extends ConsumerWidget {
  const ChatArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDesk = ref.watch(selectedDeskProvider);

    if (selectedDesk == null) {
      return const _NoDeskSelected();
    }

    return Column(
      children: [
        _ChatHeader(desk: selectedDesk),
        const Expanded(child: MessageList()),
        const _BottomArea(),
      ],
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  final DeskInfo desk;

  const _ChatHeader({required this.desk});

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
          // Left side: desk info
          Text(desk.deviceIcon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              desk.deskName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: NordColors.nord5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          _StateBadge(state: claudeState),

          const Spacer(),

          // Right side: session menu button
          _SessionMenuButton(desk: desk),
        ],
      ),
    );
  }
}

class _SessionMenuButton extends ConsumerWidget {
  final DeskInfo desk;

  const _SessionMenuButton({required this.desk});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
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
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'permission',
          child: Row(
            children: [
              Icon(Icons.security, color: NordColors.nord5, size: 18),
              SizedBox(width: 8),
              Text('퍼미션 설정', style: TextStyle(color: NordColors.nord5)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'deploy',
          child: Row(
            children: [
              Icon(Icons.rocket_launch, color: NordColors.nord13, size: 18),
              SizedBox(width: 8),
              Text('배포', style: TextStyle(color: NordColors.nord13)),
            ],
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'new_session':
        _showNewSessionDialog(context, ref);
        break;
      case 'compact':
        ref.read(relayServiceProvider).sendClaudeControl(
          desk.deviceId,
          desk.deskId,
          'compact',
        );
        break;
      case 'permission':
        _showPermissionDialog(context, ref);
        break;
      case 'deploy':
        _showDeployDialog(context, ref);
        break;
    }
  }

  void _showNewSessionDialog(BuildContext context, WidgetRef ref) {
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
                desk.deviceId,
                desk.deskId,
                'new_session',
              );
              ref.read(claudeMessagesProvider.notifier).clearMessages();
              ref.read(claudeMessagesProvider.notifier).clearDeskCache(desk.deskId);
              Navigator.pop(context);
            },
            child: const Text('새 세션 시작'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog(BuildContext context, WidgetRef ref) {
    // TODO: 퍼미션 설정 다이얼로그 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('퍼미션 설정은 아직 준비 중입니다.')),
    );
  }

  void _showDeployDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DeployDialog(),
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

    // 권한/질문 요청이 있으면 RequestBar
    if (currentRequest != null) {
      return const RequestBar();
    }

    // 그 외에는 InputBar (히스토리 기반이므로 resume 자동 처리)
    return const InputBar();
  }
}

class _NoDeskSelected extends StatelessWidget {
  const _NoDeskSelected();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '좌측에서 데스크를 선택하거나 생성해주세요.',
        style: TextStyle(
          fontSize: 16,
          color: NordColors.nord3,
        ),
      ),
    );
  }
}
