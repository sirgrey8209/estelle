import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/workspace_info.dart';
import '../../../state/providers/workspace_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../common/status_dot.dart';

enum _EditMode { none, rename, delete }

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
  _EditMode _editMode = _EditMode.none;
  final TextEditingController _renameController = TextEditingController();

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = ref.watch(selectedItemProvider);
    final isThisWorkspaceSelected = selectedItem?.workspaceId == widget.workspace.workspaceId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 워크스페이스 헤더
        if (_editMode == _EditMode.none)
          _WorkspaceHeader(
            workspace: widget.workspace,
            pylonIcon: widget.pylonIcon,
            isExpanded: _isExpanded,
            isSelected: isThisWorkspaceSelected,
            priorityStatus: widget.workspace.priorityStatus,
            onToggle: () => setState(() => _isExpanded = !_isExpanded),
            onRename: () {
              setState(() {
                _editMode = _EditMode.rename;
                _renameController.text = widget.workspace.name;
              });
            },
            onDelete: () => setState(() => _editMode = _EditMode.delete),
            onAddConversation: _addConversation,
          )
        else if (_editMode == _EditMode.rename)
          _RenameRow(
            icon: widget.pylonIcon,
            controller: _renameController,
            onConfirm: _confirmRename,
            onCancel: _cancelEdit,
            isWorkspace: true,
          )
        else if (_editMode == _EditMode.delete)
          _DeleteConfirmRow(
            icon: widget.pylonIcon,
            name: widget.workspace.name,
            onConfirm: _confirmDelete,
            onCancel: _cancelEdit,
            isWorkspace: true,
          ),

        // 대화/태스크 목록 (펼쳐진 경우)
        if (_isExpanded && _editMode == _EditMode.none) ...[
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

          ],

        const SizedBox(height: 8),
      ],
    );
  }

  void _addConversation({required String skillType, required String name}) {
    ref.read(pylonWorkspacesProvider.notifier).createConversation(
      widget.workspace.deviceId,
      widget.workspace.workspaceId,
      name: name,
      skillType: skillType,
    );
  }

  void _confirmRename() {
    final newName = _renameController.text.trim();
    if (newName.isNotEmpty && newName != widget.workspace.name) {
      ref.read(pylonWorkspacesProvider.notifier).renameWorkspace(
        widget.workspace.deviceId,
        widget.workspace.workspaceId,
        newName,
      );
    }
    _cancelEdit();
  }

  void _confirmDelete() {
    ref.read(pylonWorkspacesProvider.notifier).deleteWorkspace(
      widget.workspace.deviceId,
      widget.workspace.workspaceId,
    );
    _cancelEdit();
  }

  void _cancelEdit() {
    setState(() => _editMode = _EditMode.none);
  }
}

/// 워크스페이스 헤더 - 더 눈에 띄게
class _WorkspaceHeader extends StatefulWidget {
  final WorkspaceInfo workspace;
  final String pylonIcon;
  final bool isExpanded;
  final bool isSelected;
  final String priorityStatus;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function({required String skillType, required String name}) onAddConversation;

  const _WorkspaceHeader({
    required this.workspace,
    required this.pylonIcon,
    required this.isExpanded,
    required this.isSelected,
    required this.priorityStatus,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    required this.onAddConversation,
  });

  @override
  State<_WorkspaceHeader> createState() => _WorkspaceHeaderState();
}

class _WorkspaceHeaderState extends State<_WorkspaceHeader> with SingleTickerProviderStateMixin {
  bool _isLongPressing = false;
  late AnimationController _longPressController;

  String get _actionId => 'ws_${widget.workspace.workspaceId}';

  @override
  void initState() {
    super.initState();
    _longPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _longPressController.dispose();
    super.dispose();
  }

  void _onLongPressComplete(WidgetRef ref) {
    ref.read(activeActionItemProvider.notifier).state = _actionId;
    setState(() => _isLongPressing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final activeId = ref.watch(activeActionItemProvider);
        final showActions = activeId == _actionId;

        // 애니메이션 완료 리스너 설정
        _longPressController.removeStatusListener((_) {});
        _longPressController.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _onLongPressComplete(ref);
          }
        });

        return GestureDetector(
          onLongPressStart: (_) {
            setState(() => _isLongPressing = true);
            _longPressController.forward(from: 0);
          },
          onLongPressEnd: (_) {
            if (!showActions) {
              _longPressController.reset();
              setState(() => _isLongPressing = false);
            }
          },
          onTap: () {
            if (showActions) {
              ref.read(activeActionItemProvider.notifier).state = null;
            } else {
              widget.onToggle();
            }
          },
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isSelected ? AppColors.sidebarSelected : null,
          border: Border(
            left: BorderSide(
              color: widget.isSelected ? AppColors.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // 펼침/접힘 아이콘
            Icon(
              widget.isExpanded ? Icons.expand_more : Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),

            // Pylon 아이콘
            if (widget.pylonIcon.isNotEmpty)
              Text(widget.pylonIcon, style: const TextStyle(fontSize: 16)),
            if (widget.pylonIcon.isNotEmpty)
              const SizedBox(width: 8),

            // 워크스페이스 이름
            Expanded(
              child: Text(
                widget.workspace.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 상태 점 (idle이 아닐 때)
            if (widget.priorityStatus != 'idle' && !showActions && !_isLongPressing)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: StatusDot(status: widget.priorityStatus),
              ),

            // 롱프레스 진행 표시
            if (_isLongPressing)
              AnimatedBuilder(
                animation: _longPressController,
                builder: (context, child) => SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    value: _longPressController.value,
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              )
            // 편집 버튼들 (롱프레스 완료 시)
            else if (showActions) ...[
              _MiniIconButton(
                icon: Icons.edit,
                onTap: () {
                  ref.read(activeActionItemProvider.notifier).state = null;
                  widget.onRename();
                },
              ),
              _MiniIconButton(
                icon: Icons.delete,
                onTap: () {
                  ref.read(activeActionItemProvider.notifier).state = null;
                  widget.onDelete();
                },
                color: AppColors.statusError,
              ),
            ] else
              // + 버튼 (대화 추가)
              _AddButton(
                onAdd: widget.onAddConversation,
                existingConversations: widget.workspace.conversations,
              ),
          ],
        ),
      ),
        );
      },
    );
  }
}

/// 대화 항목
class _ConversationItem extends ConsumerStatefulWidget {
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
  ConsumerState<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends ConsumerState<_ConversationItem> with SingleTickerProviderStateMixin {
  _EditMode _editMode = _EditMode.none;
  bool _isLongPressing = false;
  late AnimationController _longPressController;
  final TextEditingController _renameController = TextEditingController();

  String get _actionId => 'conv_${widget.conversation.conversationId}';

  @override
  void initState() {
    super.initState();
    _longPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _longPressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        ref.read(activeActionItemProvider.notifier).state = _actionId;
        setState(() => _isLongPressing = false);
      }
    });
  }

  @override
  void dispose() {
    _longPressController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeId = ref.watch(activeActionItemProvider);
    final showActions = activeId == _actionId;

    if (_editMode == _EditMode.rename) {
      return _RenameRow(
        icon: '',
        controller: _renameController,
        onConfirm: _confirmRename,
        onCancel: _cancelEdit,
        isWorkspace: false,
      );
    }

    if (_editMode == _EditMode.delete) {
      return _DeleteConfirmRow(
        icon: '',
        name: widget.conversation.name,
        onConfirm: _confirmDelete,
        onCancel: _cancelEdit,
        isWorkspace: false,
      );
    }

    return GestureDetector(
      onLongPressStart: (_) {
        setState(() => _isLongPressing = true);
        _longPressController.forward(from: 0);
      },
      onLongPressEnd: (_) {
        if (!showActions) {
          _longPressController.reset();
          setState(() => _isLongPressing = false);
        }
      },
      onTap: () {
        if (showActions) {
          ref.read(activeActionItemProvider.notifier).state = null;
        } else {
          ref.read(selectedItemProvider.notifier).selectConversation(
            widget.deviceId, widget.workspaceId, widget.conversation.conversationId,
          );
          // 모바일에서 같은 대화를 다시 눌러도 채팅 탭으로 이동하기 위한 이벤트
          ref.read(conversationTapEventProvider.notifier).state = DateTime.now();
        }
      },
      child: Container(
        padding: const EdgeInsets.only(left: 44, right: 8, top: 6, bottom: 6),
        color: widget.isSelected ? AppColors.sidebarSelected.withOpacity(0.5) : null,
        child: Row(
          children: [
            // 스킬 타입 아이콘
            Text(
              widget.conversation.skillIcon,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 6),

            // 대화 이름
            Expanded(
              child: Text(
                widget.conversation.name,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 롱프레스 진행 표시
            if (_isLongPressing)
              AnimatedBuilder(
                animation: _longPressController,
                builder: (context, child) => SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    value: _longPressController.value,
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              )
            // 편집 버튼들 (롱프레스 완료 시)
            else if (showActions) ...[
              _MiniIconButton(
                icon: Icons.edit,
                onTap: () {
                  ref.read(activeActionItemProvider.notifier).state = null;
                  setState(() {
                    _editMode = _EditMode.rename;
                    _renameController.text = widget.conversation.name;
                  });
                },
                size: 14,
              ),
              _MiniIconButton(
                icon: Icons.delete,
                onTap: () {
                  ref.read(activeActionItemProvider.notifier).state = null;
                  setState(() => _editMode = _EditMode.delete);
                },
                color: AppColors.statusError,
                size: 14,
              ),
            ] else
              StatusDot(status: _getConversationStatus()),
          ],
        ),
      ),
    );
  }

  String _getConversationStatus() {
    return widget.conversation.dotStatus;
  }

  void _confirmRename() {
    final newName = _renameController.text.trim();
    if (newName.isNotEmpty && newName != widget.conversation.name) {
      ref.read(pylonWorkspacesProvider.notifier).renameConversation(
        widget.deviceId,
        widget.workspaceId,
        widget.conversation.conversationId,
        newName,
      );
    }
    _cancelEdit();
  }

  void _confirmDelete() {
    ref.read(pylonWorkspacesProvider.notifier).deleteConversation(
      widget.deviceId,
      widget.workspaceId,
      widget.conversation.conversationId,
    );
    _cancelEdit();
  }

  void _cancelEdit() {
    setState(() => _editMode = _EditMode.none);
  }
}

/// 태스크 항목
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
        padding: const EdgeInsets.only(left: 44, right: 8, top: 6, bottom: 6),
        color: isSelected ? AppColors.sidebarSelected.withOpacity(0.5) : null,
        child: Row(
          children: [
            Icon(
              Icons.task_alt,
              size: 14,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
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
            StatusDot(status: _getTaskStatus()),
          ],
        ),
      ),
    );
  }

  String _getTaskStatus() {
    if (task.isFailed) return 'error';
    if (task.isRunning) return 'working';
    if (task.isDone) return 'done';
    return 'idle';
  }
}

/// + 버튼 (대화 생성 다이얼로그)
class _AddButton extends StatelessWidget {
  final void Function({required String skillType, required String name}) onAdd;
  final List<ConversationInfo> existingConversations;

  const _AddButton({
    required this.onAdd,
    required this.existingConversations,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showCreateDialog(context),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.add,
          size: 18,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _NewConversationDialog(
        existingConversations: existingConversations,
        onConfirm: (skillType, name) {
          onAdd(skillType: skillType, name: name);
        },
      ),
    );
  }
}

/// 새 대화 생성 다이얼로그
class _NewConversationDialog extends StatefulWidget {
  final List<ConversationInfo> existingConversations;
  final void Function(String skillType, String name) onConfirm;

  const _NewConversationDialog({
    required this.existingConversations,
    required this.onConfirm,
  });

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  static const _skillTypes = [
    ('general', '💬', '대화'),
    ('planner', '📋', '플랜'),
    ('worker', '🔧', '구현'),
  ];

  int _selectedIndex = 0;
  late TextEditingController _nameController;
  bool _nameManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _generateDefaultName());
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    // 사용자가 직접 수정했는지 체크
    final defaultName = _generateDefaultName();
    if (_nameController.text != defaultName) {
      _nameManuallyEdited = true;
    }
  }

  String _generateDefaultName() {
    final skillType = _skillTypes[_selectedIndex];
    final baseName = skillType.$3;

    // 동일 이름 개수 찾기
    int count = 1;
    while (true) {
      final name = '$baseName$count';
      final exists = widget.existingConversations.any((c) => c.name == name);
      if (!exists) break;
      count++;
    }
    return '$baseName$count';
  }

  void _cycleSkillType() {
    setState(() {
      _selectedIndex = (_selectedIndex + 1) % _skillTypes.length;
      // 이름을 직접 수정하지 않았으면 기본 이름 업데이트
      if (!_nameManuallyEdited) {
        _nameController.text = _generateDefaultName();
      }
    });
  }

  void _confirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    widget.onConfirm(_skillTypes[_selectedIndex].$1, name);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final skill = _skillTypes[_selectedIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      contentPadding: EdgeInsets.all(isMobile ? 16 : 20),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 페르소나 사이클 버튼
            InkWell(
              onTap: _cycleSkillType,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.sidebarSelected,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(skill.$2, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Text(
                      skill.$3,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.swap_horiz,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 대화명 입력
            TextField(
              controller: _nameController,
              autofocus: true,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: '대화명',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.sidebarBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('취소', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('생성'),
        ),
      ],
    );
  }
}

/// 작은 아이콘 버튼
class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  const _MiniIconButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: size,
          color: color ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// 이름 변경 행
class _RenameRow extends StatelessWidget {
  final String icon;
  final TextEditingController controller;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isWorkspace;

  const _RenameRow({
    required this.icon,
    required this.controller,
    required this.onConfirm,
    required this.onCancel,
    required this.isWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: isWorkspace ? 8 : 44,
        right: 4,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        children: [
          if (isWorkspace) ...[
            const SizedBox(width: 20), // 펼침 아이콘 자리
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                fontSize: isWorkspace ? 14 : 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
              onSubmitted: (_) => onConfirm(),
            ),
          ),
          _MiniIconButton(
            icon: Icons.check,
            onTap: onConfirm,
            color: AppColors.statusSuccess,
          ),
          _MiniIconButton(
            icon: Icons.close,
            onTap: onCancel,
          ),
        ],
      ),
    );
  }
}

/// 삭제 확인 행
class _DeleteConfirmRow extends StatelessWidget {
  final String icon;
  final String name;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isWorkspace;

  const _DeleteConfirmRow({
    required this.icon,
    required this.name,
    required this.onConfirm,
    required this.onCancel,
    required this.isWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: isWorkspace ? 8 : 44,
        right: 4,
        top: 6,
        bottom: 6,
      ),
      color: AppColors.statusError.withOpacity(0.1),
      child: Row(
        children: [
          if (isWorkspace) ...[
            const SizedBox(width: 20),
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              '삭제하시겠습니까?',
              style: TextStyle(
                fontSize: isWorkspace ? 14 : 13,
                color: AppColors.statusError,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _MiniIconButton(
            icon: Icons.check,
            onTap: onConfirm,
            color: AppColors.statusError,
          ),
          _MiniIconButton(
            icon: Icons.close,
            onTap: onCancel,
          ),
        ],
      ),
    );
  }
}

