import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/workspace_info.dart';
import '../../../state/providers/workspace_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'workspace_item.dart';
import 'new_workspace_dialog.dart';

/// 워크스페이스 기반 사이드바
class WorkspaceSidebar extends ConsumerWidget {
  const WorkspaceSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pylons = ref.watch(pylonListWorkspacesProvider);

    return Container(
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          Expanded(
            child: pylons.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: pylons.length,
                    itemBuilder: (context, index) {
                      final pylon = pylons[index];
                      return _PylonWorkspaceGroup(pylon: pylon);
                    },
                  ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _AddWorkspaceButton(pylons: pylons),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, size: 48, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text(
            '워크스페이스가 없습니다',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PylonWorkspaceGroup extends ConsumerWidget {
  final PylonWorkspaces pylon;

  const _PylonWorkspaceGroup({required this.pylon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final workspace in pylon.workspaces)
          WorkspaceItem(
            workspace: workspace,
            pylonIcon: pylon.icon,
          ),
      ],
    );
  }
}

class _AddWorkspaceButton extends ConsumerWidget {
  final List<PylonWorkspaces> pylons;

  const _AddWorkspaceButton({required this.pylons});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: pylons.isEmpty
          ? null
          : () => _showNewWorkspaceDialog(context, ref, pylons),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.add,
              size: 20,
              color: pylons.isEmpty ? AppColors.textMuted : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              '워크스페이스 추가',
              style: TextStyle(
                color: pylons.isEmpty ? AppColors.textMuted : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewWorkspaceDialog(
    BuildContext context,
    WidgetRef ref,
    List<PylonWorkspaces> pylons,
  ) {
    showDialog(
      context: context,
      builder: (context) => NewWorkspaceDialog(pylons: pylons),
    );
  }
}
