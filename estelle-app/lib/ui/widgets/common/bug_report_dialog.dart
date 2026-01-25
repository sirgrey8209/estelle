import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../state/providers/relay_provider.dart';
import '../../../state/providers/workspace_provider.dart';

class BugReportDialog extends ConsumerStatefulWidget {
  const BugReportDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BugReportDialog(),
    );
  }

  @override
  ConsumerState<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends ConsumerState<BugReportDialog> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    setState(() => _sending = true);

    try {
      final relay = ref.read(relayServiceProvider);
      final selectedItem = ref.read(selectedItemProvider);

      relay.sendBugReport(
        message: message,
        conversationId: selectedItem?.itemId,
        workspaceId: selectedItem?.workspaceId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('버그 리포트가 전송되었습니다.'),
            backgroundColor: NordColors.nord14,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('전송 실패: $e'),
            backgroundColor: NordColors.nord11,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NordColors.nord1,
      title: const Row(
        children: [
          Icon(Icons.bug_report, color: NordColors.nord11, size: 24),
          SizedBox(width: 8),
          Text(
            '버그 리포트',
            style: TextStyle(color: NordColors.nord5, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '문제를 설명해주세요:',
              style: TextStyle(color: NordColors.nord4, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 5,
              style: const TextStyle(color: NordColors.nord5, fontSize: 14),
              decoration: InputDecoration(
                hintText: '어떤 문제가 발생했나요?',
                hintStyle: TextStyle(color: NordColors.nord3),
                filled: true,
                fillColor: NordColors.nord0,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: NordColors.nord8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '현재 대화/워크스페이스 정보가 함께 전송됩니다.',
              style: TextStyle(color: NordColors.nord3, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('취소', style: TextStyle(color: NordColors.nord4)),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: NordColors.nord11,
            foregroundColor: NordColors.nord6,
          ),
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: NordColors.nord6),
                )
              : const Text('전송'),
        ),
      ],
    );
  }
}
