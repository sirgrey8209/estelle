import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../state/providers/relay_provider.dart';
import '../../state/providers/workspace_provider.dart';
import '../widgets/chat/chat_area.dart';
import '../widgets/sidebar/workspace_sidebar.dart';
import '../widgets/task/task_detail_view.dart';
import '../widgets/settings/settings_screen.dart';
import '../widgets/common/loading_overlay.dart';
import '../widgets/common/bug_report_dialog.dart';

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

  // Triple tap detection
  int _tapCount = 0;
  DateTime? _lastTapTime;

  static const int _pageCount = 3; // Workspaces, Claude, Settings

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 400) {
      _tapCount++;
      if (_tapCount >= 3) {
        _tapCount = 0;
        _lastTapTime = null;
        BugReportDialog.show(context);
      }
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;
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

  bool _shouldShowOverlay(LoadingState loadingState, int page) {
    switch (page) {
      case 0:
        return loadingState == LoadingState.connecting ||
            loadingState == LoadingState.loadingWorkspaces;
      case 1:
        return loadingState == LoadingState.connecting ||
            loadingState == LoadingState.loadingWorkspaces;
      case 2:
        return loadingState == LoadingState.connecting;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionAsync.valueOrNull ?? ref.read(relayServiceProvider).isConnected;
    final loadingState = ref.watch(loadingStateProvider);
    final pylonWorkspaces = ref.watch(pylonWorkspacesProvider);
    final selectedItem = ref.watch(selectedItemProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: NordColors.nord1,
        title: Row(
          children: [
            if (_currentPage == 0) ...[
              const Text(
                'Workspaces',
                style: TextStyle(fontSize: 18, color: NordColors.nord6),
              ),
            ] else if (_currentPage == 1 && selectedItem != null) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => _goToPage(0),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedItem.isTask ? '📋 태스크' : '💬 대화',
                  style: const TextStyle(fontSize: 16, color: NordColors.nord5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                  ...pylonWorkspaces.values.map((pylon) {
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
      ),
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.translucent,
        child: Stack(
        children: [
          Column(
            children: [
              // Tab navigation bar
              _TabBar(
                currentPage: _currentPage,
                onTabSelected: _goToPage,
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
                      // Page 0: Workspace List
                      const WorkspaceSidebar(),
                      // Page 1: Chat or Task
                      selectedItem?.isTask == true
                          ? const TaskDetailView()
                          : const ChatArea(showHeader: false),
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
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int currentPage;
  final ValueChanged<int> onTabSelected;

  const _TabBar({
    required this.currentPage,
    required this.onTabSelected,
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
            label: 'Workspaces',
            icon: Icons.workspaces,
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
