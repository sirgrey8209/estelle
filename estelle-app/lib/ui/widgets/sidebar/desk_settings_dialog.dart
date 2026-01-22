import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/desk_info.dart';
import '../../../state/providers/relay_provider.dart';
import '../../../state/providers/desk_provider.dart';
import '../../../state/providers/claude_provider.dart';

class DeskSettingsDialog extends ConsumerStatefulWidget {
  final DeskInfo desk;

  const DeskSettingsDialog({super.key, required this.desk});

  @override
  ConsumerState<DeskSettingsDialog> createState() => _DeskSettingsDialogState();
}

class _DeskSettingsDialogState extends ConsumerState<DeskSettingsDialog> {
  bool _isRenaming = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.desk.deskName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _rename() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.desk.deskName) {
      ref.read(relayServiceProvider).renameDesk(
        widget.desk.deviceId,
        widget.desk.deskId,
        newName,
      );
    }
    Navigator.of(context).pop();
  }

  void _cancelRename() {
    Navigator.of(context).pop();
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NordColors.nord1,
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        content: Text(
          '"${widget.desk.deskName}" 삭제?',
          style: const TextStyle(color: NordColors.nord4, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소', style: TextStyle(color: NordColors.nord4, fontSize: 13)),
          ),
          TextButton(
            onPressed: () {
              final selectedDesk = ref.read(selectedDeskProvider);
              if (selectedDesk?.deskId == widget.desk.deskId) {
                ref.read(selectedDeskProvider.notifier).select(null);
                ref.read(claudeMessagesProvider.notifier).clearMessages();
              }
              ref.read(claudeMessagesProvider.notifier).clearDeskCache(widget.desk.deskId);
              ref.read(relayServiceProvider).deleteDesk(widget.desk.deviceId, widget.desk.deskId);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('삭제', style: TextStyle(color: NordColors.nord11, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRenaming) {
      return AlertDialog(
        backgroundColor: NordColors.nord1,
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        content: SizedBox(
          width: 200,
          child: TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(color: NordColors.nord6, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              hintText: 'Desk name',
              hintStyle: TextStyle(color: NordColors.nord4.withOpacity(0.5), fontSize: 14),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: NordColors.nord3)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: NordColors.nord8)),
            ),
            onSubmitted: (_) => _rename(),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        actions: [
          TextButton(
            onPressed: _cancelRename,
            child: const Text('취소', style: TextStyle(color: NordColors.nord4, fontSize: 13)),
          ),
          TextButton(
            onPressed: _rename,
            child: const Text('확인', style: TextStyle(color: NordColors.nord8, fontSize: 13)),
          ),
        ],
      );
    }

    return SimpleDialog(
      backgroundColor: NordColors.nord1,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _MenuItem(
          icon: Icons.edit,
          label: '이름 변경',
          onTap: () => setState(() => _isRenaming = true),
        ),
        _MenuItem(
          icon: Icons.delete_outline,
          label: '삭제',
          color: NordColors.nord11,
          onTap: _delete,
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? NordColors.nord4;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 18),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: c, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
