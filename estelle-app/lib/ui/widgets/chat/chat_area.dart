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
          Text(
            desk.deskName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: NordColors.nord5,
            ),
          ),
          const SizedBox(width: 10),
          _StateBadge(state: claudeState),

          const Spacer(),

          // Right side: controls
          _ControlButton(
            label: 'Stop',
            onPressed: claudeState == 'working'
                ? () {
                    ref.read(relayServiceProvider).sendClaudeControl(
                      desk.deviceId,
                      desk.deskId,
                      'stop',
                    );
                  }
                : null,
          ),
          const SizedBox(width: 8),
          _ControlButton(
            label: 'New Session',
            onPressed: () {
              ref.read(relayServiceProvider).sendClaudeControl(
                desk.deviceId,
                desk.deskId,
                'new_session',
              );
              ref.read(claudeMessagesProvider.notifier).clearMessages();
              ref.read(claudeMessagesProvider.notifier).clearDeskCache(desk.deskId);
            },
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

class _ControlButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Opacity(
          opacity: onPressed != null ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: NordColors.nord3,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: NordColors.nord5,
              ),
            ),
          ),
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
