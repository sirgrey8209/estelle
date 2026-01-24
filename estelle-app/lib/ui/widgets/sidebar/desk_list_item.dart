import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/desk_info.dart';
import '../../../state/providers/relay_provider.dart';
import '../../../state/providers/desk_provider.dart';
import '../../../state/providers/claude_provider.dart';

class DeskListItem extends ConsumerStatefulWidget {
  final DeskInfo desk;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showDragHandle;
  final int index;

  const DeskListItem({
    super.key,
    required this.desk,
    required this.isSelected,
    required this.onTap,
    this.showDragHandle = true,
    this.index = 0,
  });

  @override
  ConsumerState<DeskListItem> createState() => _DeskListItemState();
}

enum _EditMode { none, menu, editing, deleting }

class _DeskListItemState extends ConsumerState<DeskListItem> {
  _EditMode _mode = _EditMode.none;
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

  @override
  void didUpdateWidget(covariant DeskListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.desk.deskName != widget.desk.deskName && _mode != _EditMode.editing) {
      _nameController.text = widget.desk.deskName;
    }
  }

  void _showMenu() {
    setState(() {
      _mode = _EditMode.menu;
      _nameController.text = widget.desk.deskName;
    });
  }

  void _startEditing() {
    setState(() => _mode = _EditMode.editing);
  }

  void _startDeleting() {
    setState(() => _mode = _EditMode.deleting);
  }

  void _cancel() {
    setState(() => _mode = _EditMode.none);
  }

  void _saveEdit() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.desk.deskName) {
      ref.read(relayServiceProvider).renameDesk(
        widget.desk.deviceId,
        widget.desk.deskId,
        newName,
      );
    }
    setState(() => _mode = _EditMode.none);
  }

  void _confirmDelete() {
    final relayService = ref.read(relayServiceProvider);
    final selectedDeskNotifier = ref.read(selectedDeskProvider.notifier);
    final claudeNotifier = ref.read(claudeMessagesProvider.notifier);
    final currentSelectedDesk = ref.read(selectedDeskProvider);
    final deskToDelete = widget.desk;

    // 선택된 데스크면 선택 해제
    if (currentSelectedDesk?.deskId == deskToDelete.deskId) {
      selectedDeskNotifier.select(null);
      claudeNotifier.clearMessages();
    }
    claudeNotifier.clearDeskCache(deskToDelete.deskId);
    relayService.deleteDesk(deskToDelete.deviceId, deskToDelete.deskId);
    setState(() => _mode = _EditMode.none);
  }

  Color _getTextColor() {
    if (widget.desk.status == 'working') return NordColors.nord13;
    if (widget.desk.status == 'waiting') return NordColors.nord12;
    if (widget.desk.status == 'error') return NordColors.nord11;
    return widget.isSelected ? NordColors.nord6 : NordColors.nord4;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _mode == _EditMode.none ? widget.onTap : null,
        onLongPress: _mode == _EditMode.none ? _showMenu : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected ? NordColors.nord10 : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              // Drag handle
              if (widget.showDragHandle)
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: NordColors.nord3,
                    ),
                  ),
                ),

              // Name or TextField (editing mode)
              Expanded(
                child: _mode == _EditMode.editing
                    ? TextField(
                        controller: _nameController,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 13,
                          color: _getTextColor(),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: NordColors.nord3),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: NordColors.nord8),
                          ),
                        ),
                        onSubmitted: (_) => _saveEdit(),
                      )
                    : Text(
                        widget.desk.deskName,
                        style: TextStyle(
                          fontSize: 13,
                          color: _mode == _EditMode.deleting ? NordColors.nord11 : _getTextColor(),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),

              const SizedBox(width: 8),

              // Right side buttons based on mode
              _buildRightButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightButtons() {
    switch (_mode) {
      case _EditMode.none:
        return _StatusIndicator(status: widget.desk.status);

      case _EditMode.menu:
        // 롱클릭 후: 편집/삭제 버튼
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniButton(
              icon: Icons.edit,
              color: NordColors.nord8,
              onTap: _startEditing,
            ),
            const SizedBox(width: 4),
            _MiniButton(
              icon: Icons.delete_outline,
              color: NordColors.nord11,
              onTap: _startDeleting,
            ),
            const SizedBox(width: 4),
            _MiniButton(
              icon: Icons.close,
              color: NordColors.nord4,
              onTap: _cancel,
            ),
          ],
        );

      case _EditMode.editing:
        // 편집 모드: 확인 버튼
        return _MiniButton(
          icon: Icons.check,
          color: NordColors.nord14,
          onTap: _saveEdit,
        );

      case _EditMode.deleting:
        // 삭제 확인: 확인/취소 버튼
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniButton(
              icon: Icons.check,
              color: NordColors.nord11,
              onTap: _confirmDelete,
            ),
            const SizedBox(width: 4),
            _MiniButton(
              icon: Icons.close,
              color: NordColors.nord4,
              onTap: _cancel,
            ),
          ],
        );
    }
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: NordColors.nord2,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'working':
        return const _BlinkingDot(color: NordColors.nord13);
      case 'waiting':
        return const _StaticDot(color: NordColors.nord11);
      case 'error':
        return const Icon(Icons.close, size: 12, color: NordColors.nord11);
      case 'idle':
      default:
        return const SizedBox(width: 8);
    }
  }
}

class _StaticDot extends StatelessWidget {
  final Color color;

  const _StaticDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;

  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
