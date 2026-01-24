import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../state/providers/relay_provider.dart';

/// 퍼미션 모드 선택기
/// - default: 모든 도구에 권한 요청
/// - acceptEdits: Edit, Write, Bash 자동 허용
/// - bypassPermissions: 모든 도구 자동 허용
class PermissionModeSection extends ConsumerStatefulWidget {
  const PermissionModeSection({super.key});

  @override
  ConsumerState<PermissionModeSection> createState() => _PermissionModeSectionState();
}

class _PermissionModeSectionState extends ConsumerState<PermissionModeSection> {
  String _selectedMode = 'default';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permission Mode',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: NordColors.nord5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Controls how Claude handles tool permissions',
          style: TextStyle(
            fontSize: 12,
            color: NordColors.nord4,
          ),
        ),
        const SizedBox(height: 12),
        _buildModeOption(
          value: 'default',
          title: 'Default',
          description: 'Ask for permission on Edit, Write, Bash',
          icon: Icons.security,
        ),
        const SizedBox(height: 8),
        _buildModeOption(
          value: 'acceptEdits',
          title: 'Accept Edits',
          description: 'Auto-allow Edit, Write, Bash, NotebookEdit',
          icon: Icons.edit_note,
        ),
        const SizedBox(height: 8),
        _buildModeOption(
          value: 'bypassPermissions',
          title: 'Bypass All',
          description: 'Auto-allow all tools (use with caution)',
          icon: Icons.warning_amber,
          isWarning: true,
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required String value,
    required String title,
    required String description,
    required IconData icon,
    bool isWarning = false,
  }) {
    final isSelected = _selectedMode == value;
    final relay = ref.read(relayServiceProvider);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = value;
        });
        relay.setPermissionMode(value);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? NordColors.nord2 : NordColors.nord1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isWarning ? NordColors.nord12 : NordColors.nord8)
                : NordColors.nord3,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isWarning ? NordColors.nord12 : NordColors.nord4,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isWarning ? NordColors.nord12 : NordColors.nord5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: NordColors.nord4,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 20,
                color: isWarning ? NordColors.nord12 : NordColors.nord8,
              ),
          ],
        ),
      ),
    );
  }
}
