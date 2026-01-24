import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../data/models/desk_info.dart';
import '../../state/providers/relay_provider.dart';
import '../../state/providers/desk_provider.dart';
import '../../state/providers/claude_provider.dart';
import '../../state/providers/workspace_provider.dart';
import '../widgets/chat/chat_area.dart';
import '../widgets/sidebar/new_desk_dialog.dart';
import '../widgets/sidebar/desk_list_item.dart';
import '../widgets/sidebar/workspace_sidebar.dart';
import '../widgets/task/task_detail_view.dart';
import '../widgets/settings/settings_screen.dart';
import '../widgets/common/loading_overlay.dart';

// Permission mode constants
const _permissionModes = ['default', 'acceptEdits', 'bypassPermissions'];
const _permissionIcons = {
  'default': Icons.security,
  'acceptEdits': Icons.edit_note,
  'bypassPermissions': Icons.warning_amber,
};
const _permissionColors = {
  'default': NordColors.nord4,
  'acceptEdits': NordColors.nord8,
  'bypassPermissions': NordColors.nord12,
};

class MobileLayout extends ConsumerStatefulWidget {
  const MobileLayout({super.key});

  @override
  ConsumerState<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends ConsumerState<MobileLayout> {
  final _pageController = PageController(initialPage: 1);
  int _currentPage = 1;
  double? _dragStartX;
  double? _dragStartPage;

  static const int _pageCount = 3; // Desks, Claude, Settings

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _dragStartX = event.position.dx;
    _dragStartPage = _pageController.page;
  }

  // 드래그 비율 → lerp된 페이지 오프셋 (0~20%: 0, 20~50%: 0~1)
  double _dragToPageOffset(double dragRatio) {
    const deadZone = 0.2;
    const maxZone = 0.5;

    if (dragRatio.abs() < deadZone) return 0;

    final sign = dragRatio < 0 ? -1.0 : 1.0;
    final ratio = (dragRatio.abs() - deadZone) / (maxZone - deadZone);
    return sign * ratio.clamp(0.0, 1.0);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragStartX == null || _dragStartPage == null) return;
    if (!_pageController.hasClients) return;

    final viewportWidth = _pageController.position.viewportDimension;
    final delta = event.position.dx - _dragStartX!;
    final dragRatio = -delta / viewportWidth;

    final pageOffset = _dragToPageOffset(dragRatio);
    final newPage = (_dragStartPage! + pageOffset).clamp(0.0, _pageCount - 1.0);
    _pageController.jumpTo(newPage * viewportWidth);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_dragStartX == null || _dragStartPage == null) return;
    if (!_pageController.hasClients) return;

    final viewportWidth = _pageController.position.viewportDimension;
    final delta = event.position.dx - _dragStartX!;
    final dragRatio = -delta / viewportWidth;
    final pageOffset = _dragToPageOffset(dragRatio);
    final startPage = _dragStartPage!.round();

    _dragStartX = null;
    _dragStartPage = null;

    // pageOffset이 1이면 (= 50% 이상 드래그) 다음 탭으로 이동
    int targetPage;
    if (pageOffset.abs() >= 1.0) {
      targetPage = pageOffset > 0
          ? (startPage + 1).clamp(0, _pageCount - 1)
          : (startPage - 1).clamp(0, _pageCount - 1);
    } else {
      targetPage = startPage;
    }

    _goToPage(targetPage);
  }

  /// Check if overlay should be shown for current page
  bool _shouldShowOverlay(LoadingState loadingState, int page) {
    switch (page) {
      case 0: // Desks tab: show connecting/loadingDesks
        return loadingState == LoadingState.connecting ||
            loadingState == LoadingState.loadingDesks;
      case 1: // Claude tab: show connecting/loadingDesks/loadingMessages
        return loadingState == LoadingState.connecting ||
            loadingState == LoadingState.loadingDesks ||
            loadingState == LoadingState.loadingMessages;
      case 2: // Settings tab: show connecting only
        return loadingState == LoadingState.connecting;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionAsync.valueOrNull ?? ref.read(relayServiceProvider).isConnected;
    final selectedDesk = ref.watch(selectedDeskProvider);
    final loadingState = ref.watch(loadingStateProvider);
    final pylonWorkspaces = ref.watch(pylonWorkspacesProvider);
    final selectedItem = ref.watch(selectedItemProvider);

    // 워크스페이스 모드 여부
    final useWorkspaceMode = pylonWorkspaces.values.any((p) => p.workspaces.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: NordColors.nord1,
        title: Row(
          children: [
            if (_currentPage == 0) ...[
              Text(
                useWorkspaceMode ? 'Workspaces' : 'Desks',
                style: const TextStyle(fontSize: 18, color: NordColors.nord6),
              ),
            ] else if (_currentPage == 1 && (useWorkspaceMode || selectedDesk != null)) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => _goToPage(0),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              if (useWorkspaceMode) ...[
                // 워크스페이스 모드: 선택된 항목 표시
                Expanded(
                  child: Text(
                    selectedItem?.isTask == true ? '📋 태스크' : '💬 대화',
                    style: const TextStyle(fontSize: 16, color: NordColors.nord5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else if (selectedDesk != null) ...[
                Text(selectedDesk.deviceIcon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedDesk.deskName,
                    style: const TextStyle(fontSize: 16, color: NordColors.nord5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ] else if (_currentPage == 2) ...[
              const Icon(Icons.settings, color: NordColors.nord4, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Settings',
                style: TextStyle(fontSize: 18, color: NordColors.nord6),
              ),
            ] else ...[
              if (_currentPage == 1) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => _goToPage(0),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
              ],
              const Text(
                'Estelle',
                style: TextStyle(fontSize: 18, color: NordColors.nord6),
              ),
            ],
          ],
        ),
        actions: [
          if (_currentPage == 1 && selectedDesk != null) ...[
            // Claude tab: permission + menu buttons
            _PermissionButton(desk: selectedDesk),
            _SessionMenuButton(desk: selectedDesk),
          ] else ...[
            // Other tabs: connection status
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: NordColors.nord2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        fontSize: 11,
                        color: isConnected ? NordColors.nord14 : NordColors.nord11,
                      ),
                    ),
                  ),
                  if (isConnected) ...[
                    const SizedBox(width: 6),
                    ...ref.watch(pylonDesksProvider).values.map((pylon) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(pylon.icon, style: const TextStyle(fontSize: 14)),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Tab navigation bar
              _TabBar(
                currentPage: _currentPage,
                onTabSelected: _goToPage,
                useWorkspaceMode: useWorkspaceMode,
              ),
              // Page content
              Expanded(
                child: Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: [
                      // Page 0: List (Workspace or Desk)
                      if (useWorkspaceMode)
                        _WorkspaceListPage(onGoToChat: () => _goToPage(1))
                      else
                        _DeskListPage(
                          onDeskSelected: (desk) {
                            // 데스크 선택 처리 (저장 + 로드 + sync 요청)
                            final currentDesk = ref.read(selectedDeskProvider);
                            ref.read(claudeMessagesProvider.notifier)
                                .onDeskSelected(currentDesk, desk);
                            ref.read(selectedDeskProvider.notifier).select(desk);
                            // Go to chat
                            _goToPage(1);
                          },
                        ),
                      // Page 1: Chat or Task (hide header on mobile)
                      if (useWorkspaceMode && selectedItem?.isTask == true)
                        const TaskDetailView()
                      else
                        const ChatArea(showHeader: false),
                      // Page 2: Settings
                      const SettingsScreen(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Loading overlay (conditional per page)
          if (_shouldShowOverlay(loadingState, _currentPage))
            Positioned.fill(
              child: LoadingOverlay(state: loadingState),
            ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int currentPage;
  final ValueChanged<int> onTabSelected;
  final bool useWorkspaceMode;

  const _TabBar({
    required this.currentPage,
    required this.onTabSelected,
    this.useWorkspaceMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: NordColors.nord1,
        border: Border(
          bottom: BorderSide(color: NordColors.nord2),
        ),
      ),
      child: Row(
        children: [
          _TabItem(
            label: useWorkspaceMode ? 'Workspaces' : 'Desks',
            icon: useWorkspaceMode ? Icons.workspaces : Icons.folder,
            isSelected: currentPage == 0,
            onTap: () => onTabSelected(0),
          ),
          _TabItem(
            label: 'Claude',
            icon: Icons.chat,
            isSelected: currentPage == 1,
            onTap: () => onTabSelected(1),
          ),
          _TabItem(
            label: 'Settings',
            icon: Icons.settings,
            isSelected: currentPage == 2,
            onTap: () => onTabSelected(2),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? NordColors.nord10 : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? NordColors.nord10 : NordColors.nord4,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? NordColors.nord10 : NordColors.nord4,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeskListPage extends ConsumerWidget {
  final ValueChanged<DeskInfo> onDeskSelected;

  const _DeskListPage({required this.onDeskSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pylons = ref.watch(pylonDesksProvider);
    final selectedDesk = ref.watch(selectedDeskProvider);

    if (pylons.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No Pylons connected',
              style: TextStyle(
                color: NordColors.nord3,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Waiting for connection...',
              style: TextStyle(
                color: NordColors.nord3,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pylons.length,
      itemBuilder: (context, index) {
        final pylon = pylons.values.elementAt(index);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pylon header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: NordColors.nord2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(pylon.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pylon.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: NordColors.nord5,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showNewDeskDialog(context, pylon.deviceId),
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
            const SizedBox(height: 8),

            // Desks
            if (pylon.desks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No desks',
                  style: TextStyle(
                    color: NordColors.nord3,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ReorderableListView.builder(
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
                    final isSelected = selectedDesk?.deskId == desk.deskId;
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

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showNewDeskDialog(BuildContext context, int deviceId) {
    showDialog(
      context: context,
      builder: (context) => NewDeskDialog(deviceId: deviceId),
    );
  }
}

/// Permission mode button for mobile AppBar
class _PermissionButton extends ConsumerWidget {
  final DeskInfo desk;

  const _PermissionButton({required this.desk});

  void _cyclePermissionMode(WidgetRef ref) {
    final currentMode = ref.read(permissionModeProvider);
    final currentIndex = _permissionModes.indexOf(currentMode);
    final nextIndex = (currentIndex + 1) % _permissionModes.length;
    final nextMode = _permissionModes[nextIndex];

    ref.read(permissionModeProvider.notifier).state = nextMode;
    ref.read(relayServiceProvider).setPermissionMode(nextMode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(permissionModeProvider);

    return IconButton(
      onPressed: () => _cyclePermissionMode(ref),
      icon: Icon(
        _permissionIcons[currentMode],
        color: _permissionColors[currentMode],
        size: 20,
      ),
    );
  }
}

/// Session menu button for mobile AppBar
class _SessionMenuButton extends ConsumerWidget {
  final DeskInfo desk;

  const _SessionMenuButton({required this.desk});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: NordColors.nord5, size: 20),
      color: NordColors.nord2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) => _handleMenuAction(context, ref, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'new_session',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, color: NordColors.nord5, size: 18),
              SizedBox(width: 8),
              Text('새 세션', style: TextStyle(color: NordColors.nord5)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'compact',
          child: Row(
            children: [
              Icon(Icons.compress, color: NordColors.nord5, size: 18),
              SizedBox(width: 8),
              Text('컴팩트', style: TextStyle(color: NordColors.nord5)),
            ],
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'new_session':
        _showNewSessionDialog(context, ref);
        break;
      case 'compact':
        ref.read(relayServiceProvider).sendClaudeControl(
          desk.deviceId,
          desk.deskId,
          'compact',
        );
        break;
    }
  }

  void _showNewSessionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NordColors.nord1,
        title: const Text('새 세션', style: TextStyle(color: NordColors.nord5)),
        content: const Text(
          '현재 세션을 종료하고 새 세션을 시작할까요?\n기존 대화 내용은 삭제됩니다.',
          style: TextStyle(color: NordColors.nord4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: NordColors.nord4)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NordColors.nord11),
            onPressed: () {
              ref.read(relayServiceProvider).sendClaudeControl(
                desk.deviceId,
                desk.deskId,
                'new_session',
              );
              ref.read(claudeMessagesProvider.notifier).clearMessages();
              ref.read(claudeMessagesProvider.notifier).clearDeskCache(desk.deskId);
              Navigator.pop(context);
            },
            child: const Text('새 세션 시작'),
          ),
        ],
      ),
    );
  }
}

/// 워크스페이스 모드용 목록 페이지
class _WorkspaceListPage extends ConsumerWidget {
  final VoidCallback onGoToChat;

  const _WorkspaceListPage({required this.onGoToChat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WorkspaceSidebar를 모바일 스타일로 래핑
    return const WorkspaceSidebar();
  }
}
