import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/desk_info.dart';
import '../../../state/providers/desk_provider.dart';
import '../../../state/providers/claude_provider.dart';
import 'desk_list_item.dart';
import 'new_desk_dialog.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pylons = ref.watch(pylonDesksProvider);
    final selectedDesk = ref.watch(selectedDeskProvider);

    return Container(
      width: ResponsiveUtils.sidebarWidth,
      color: NordColors.nord1,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: NordColors.nord2),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'PYLONS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NordColors.nord3,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: pylons.isEmpty
                ? const Center(
                    child: Text(
                      'No Pylons connected',
                      style: TextStyle(
                        color: NordColors.nord3,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: pylons.length,
                    itemBuilder: (context, index) {
                      final pylon = pylons.values.elementAt(index);
                      return _PylonGroup(
                        pylon: pylon,
                        selectedDesk: selectedDesk,
                        onDeskSelected: (desk) {
                          // 데스크 선택 처리 (저장 + 로드 + sync 요청)
                          ref.read(claudeMessagesProvider.notifier)
                              .onDeskSelected(selectedDesk, desk);
                          // Select new desk
                          ref.read(selectedDeskProvider.notifier).select(desk);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PylonGroup extends ConsumerWidget {
  final PylonInfo pylon;
  final DeskInfo? selectedDesk;
  final ValueChanged<DeskInfo> onDeskSelected;

  const _PylonGroup({
    required this.pylon,
    this.selectedDesk,
    required this.onDeskSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pylon header
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: NordColors.nord2,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Text(pylon.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pylon.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NordColors.nord5,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showNewDeskDialog(context),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: NordColors.nord3,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 16,
                    color: NordColors.nord4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Desk list
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: pylon.desks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'No desks',
                    style: TextStyle(
                      color: NordColors.nord3,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: pylon.desks.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    ref.read(pylonDesksProvider.notifier).reorderDesks(
                      pylon.deviceId,
                      oldIndex,
                      newIndex,
                    );
                  },
                  itemBuilder: (context, index) {
                    final desk = pylon.desks[index];
                    final isSelected = selectedDesk?.deskId == desk.deskId &&
                        selectedDesk?.deviceId == desk.deviceId;
                    return DeskListItem(
                      key: ValueKey(desk.deskId),
                      desk: desk,
                      isSelected: isSelected,
                      onTap: () => onDeskSelected(desk),
                      index: index,
                    );
                  },
                ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  void _showNewDeskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => NewDeskDialog(deviceId: pylon.deviceId),
    );
  }
}
