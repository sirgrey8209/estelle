import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../state/providers/relay_provider.dart';

class NewDeskDialog extends ConsumerStatefulWidget {
  final int deviceId;

  const NewDeskDialog({super.key, required this.deviceId});

  @override
  ConsumerState<NewDeskDialog> createState() => _NewDeskDialogState();
}

class _NewDeskDialogState extends ConsumerState<NewDeskDialog> {
  final _nameController = TextEditingController();
  final _dirController = TextEditingController(text: r'C:\Workspace');

  @override
  void dispose() {
    _nameController.dispose();
    _dirController.dispose();
    super.dispose();
  }

  void _create() {
    if (_nameController.text.trim().isEmpty) return;

    ref.read(relayServiceProvider).createDesk(
      widget.deviceId,
      _nameController.text.trim(),
      _dirController.text.trim(),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NordColors.nord1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Desk',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NordColors.nord6,
              ),
            ),
            const SizedBox(height: 20),

            // Name field
            const Text(
              'Name',
              style: TextStyle(
                fontSize: 13,
                color: NordColors.nord4,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: NordColors.nord5),
              decoration: const InputDecoration(
                hintText: 'Project name...',
              ),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 16),

            // Working directory field
            const Text(
              'Working Directory',
              style: TextStyle(
                fontSize: 13,
                color: NordColors.nord4,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _dirController,
              style: const TextStyle(color: NordColors.nord5),
              decoration: const InputDecoration(
                hintText: r'C:\Workspace\...',
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _create,
                  child: const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
