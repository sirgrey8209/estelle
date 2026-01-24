import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/workspace_info.dart';
import '../../../state/providers/workspace_provider.dart';
import '../../../core/theme/app_colors.dart';

/// 워크스페이스 항목 (펼침/접힘 가능)
class WorkspaceItem extends ConsumerStatefulWidget {
  final WorkspaceInfo workspace;
  final String pylonIcon;

  const WorkspaceItem({
    super.key,
    required this.workspace,
    required this.pylonIcon,
  });

  @override
  ConsumerState<WorkspaceItem> createState() => _WorkspaceItemState();
}

class _WorkspaceItemState extends ConsumerState<WorkspaceItem> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final selectedItem = ref.watch(selectedItemProvider);
    final isThisWorkspaceSelected = selectedItem?.workspaceId == widget.workspace.workspaceId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 워크스페이스 헤더
        _WorkspaceHeader(
          workspace: widget.workspace,
          pylonIcon: widget.pylonIcon,
          isExpanded: _isExpanded,
          isSelected: isThisWorkspaceSelected,
          priorityStatus: widget.workspace.priorityStatus,
          onToggle: () => setState(() => _isExpanded = !_isExpanded),
          onAddConversation: _addConversation,
        ),

        // 대화/태스크 목록 (펼쳐진 경우)
        if (_isExpanded) ...[
          // 대화 목록
          for (final conv in widget.workspace.conversations)
            _ConversationItem(
              conversation: conv,
              workspaceId: widget.workspace.workspaceId,
              deviceId: widget.workspace.deviceId,
              isSelected: selectedItem?.isConversation == true &&
                  selectedItem?.itemId == conv.conversationId,
            ),

          // 태스크 목록
          for (final task in widget.workspace.tasks)
            _TaskItem(
              task: task,
              workspaceId: widget.workspace.workspaceId,
              deviceId: widget.workspace.deviceId,
              isSelected: selectedItem?.isTask == true &&
                  selectedItem?.itemId == task.id,
            ),

          // [+] 대화 추가 버튼
          _AddConversationButton(
            onTap: _addConversation,
          ),
        ],

        const SizedBox(height: 4),
      ],
    );
  }

  void _addConversation() {
    ref.read(pylonWorkspacesProvider.notifier).createConversation(
      widget.workspace.deviceId,
      widget.workspace.workspaceId,
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final WorkspaceInfo workspace;
  final String pylonIcon;
  final bool isExpanded;
  final bool isSelected;
  final String priorityStatus;
  final VoidCallback onToggle;
  final VoidCallback onAddConversation;

  const _WorkspaceHeader({
    required this.workspace,
    required this.pylonIcon,
    required this.isExpanded,
    required this.isSelected,
    required this.priorityStatus,
    required this.onToggle,
    required this.onAddConversation,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: isSelected ? AppColors.sidebarSelected : null,
        child: Row(
          children: [
            // 펼침/접힘 아이콘
            Icon(
              isExpanded ? Icons.expand_more : Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),

            // Pylon 아이콘
            Text(pylonIcon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),

            // 워크스페이스 이름
            Expanded(
              child: Text(
                workspace.name,
                style: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 상태 닷 (접힌 상태일 때만, 또는 항상)
            if (!isExpanded || priorityStatus != 'idle')
              _StatusDot(status: priorityStatus),
          ],
        ),
      ),
    );
  }
}

class _ConversationItem extends ConsumerWidget {
  final ConversationInfo conversation;
  final String workspaceId;
  final int deviceId;
  final bool isSelected;

  const _ConversationItem({
    required this.conversation,
    required this.workspaceId,
    required this.deviceId,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        ref.read(selectedItemProvider.notifier).selectConversation(
          deviceId, workspaceId, conversation.conversationId,
        );
      },
      child: Container(
        padding: const EdgeInsets.only(left: 32, right: 8, top: 4, bottom: 4),
        color: isSelected ? AppColors.sidebarSelected : null,
        child: Row(
          children: [
            const Text('', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                conversation.name,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _StatusDot(status: _getConversationStatus()),
          ],
        ),
      ),
    );
  }

  String _getConversationStatus() {
    if (conversation.hasError) return 'error';
    if (conversation.isWorking || conversation.isWaiting) return 'working';
    if (conversation.unread) return 'unread';
    return 'idle';
  }
}

class _TaskItem extends ConsumerWidget {
  final TaskInfo task;
  final String workspaceId;
  final int deviceId;
  final bool isSelected;

  const _TaskItem({
    required this.task,
    required this.workspaceId,
    required this.deviceId,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        ref.read(selectedItemProvider.notifier).selectTask(
          deviceId, workspaceId, task.id,
        );
      },
      child: Container(
        padding: const EdgeInsets.only(left: 32, right: 8, top: 4, bottom: 4),
        color: isSelected ? AppColors.sidebarSelected : null,
        child: Row(
          children: [
            const Text('', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _StatusDot(status: _getTaskStatus()),
          ],
        ),
      ),
    );
  }

  String _getTaskStatus() {
    if (task.isFailed) return 'error';
    if (task.isRunning) return 'working';
    if (task.isDone) return 'done';
    return 'idle'; // pending
  }
}

class _AddConversationButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddConversationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 32, right: 8, top: 4, bottom: 4),
        child: Row(
          children: [
            Icon(Icons.add, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              '새 대화',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    if (color == null) return const SizedBox.shrink();

    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color? _getColor() {
    switch (status) {
      case 'error':
        return AppColors.statusError;
      case 'working':
        return AppColors.statusWorking;
      case 'unread':
      case 'done':
        return AppColors.statusSuccess;
      default:
        return null;
    }
  }
}
