import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import '../../../core/constants/colors.dart';
import '../../../state/providers/desk_provider.dart';
import '../../../state/providers/claude_provider.dart';
import '../../../state/providers/relay_provider.dart';

class InputBar extends ConsumerStatefulWidget {
  const InputBar({super.key});

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final desk = ref.read(selectedDeskProvider);
    if (desk == null) return;

    // 작업 중이면 전송 안함
    final claudeState = ref.read(claudeStateProvider);
    if (claudeState == 'working') return;

    // 전송 중 placeholder 표시 (Pylon에서 userMessage 이벤트 오면 실제 메시지로 대체)
    ref.read(sendingMessageProvider.notifier).state = text;

    // Send to relay
    ref.read(relayServiceProvider).sendClaudeMessage(
      desk.deviceId,
      desk.deskId,
      text,
    );

    // Update state
    ref.read(claudeStateProvider.notifier).state = 'working';
    ref.read(isThinkingProvider.notifier).state = true;
    ref.read(workStartTimeProvider.notifier).state = DateTime.now();

    // Clear input
    _controller.clear();
  }

  void _stop() {
    final desk = ref.read(selectedDeskProvider);
    if (desk == null) return;

    ref.read(relayServiceProvider).sendClaudeControl(
      desk.deviceId,
      desk.deskId,
      'stop',
    );
  }

  @override
  Widget build(BuildContext context) {
    final claudeState = ref.watch(claudeStateProvider);
    final isWorking = claudeState == 'working';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: NordColors.nord1,
        border: Border(
          top: BorderSide(color: NordColors.nord2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) {
                // Desktop만: Enter=전송, Shift+Enter 또는 Ctrl+Enter=줄바꿈
                final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
                if (isDesktop &&
                    event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed &&
                    !HardwareKeyboard.instance.isControlPressed) {
                  _send();
                  return KeyEventResult.handled; // 이벤트 소비 → 엔터 잔류 방지
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: true, // 항상 활성화 (미리 입력 가능)
                maxLines: null,
                minLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  color: NordColors.nord5,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: NordColors.nord3),
                  filled: true,
                  fillColor: NordColors.nord0,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: NordColors.nord2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: NordColors.nord2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: NordColors.nord9),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          isWorking
              ? ElevatedButton(
                  onPressed: _stop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NordColors.nord11, // 빨간색
                    foregroundColor: NordColors.nord6,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Stop'),
                )
              : ElevatedButton(
                  onPressed: !_hasText ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NordColors.nord10,
                    foregroundColor: NordColors.nord6,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Send'),
                ),
        ],
      ),
    );
  }
}
