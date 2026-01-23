import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import 'settings_screen.dart';

/// Desktop용 설정 다이얼로그
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NordColors.nord1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: NordColors.nord2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings, color: NordColors.nord4, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: NordColors.nord5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: NordColors.nord4, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Content
            const Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: SettingsContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
