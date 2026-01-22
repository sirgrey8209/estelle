import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../data/models/desk_info.dart';
import '../../state/providers/relay_provider.dart';
import '../../state/providers/desk_provider.dart';
import '../../state/providers/claude_provider.dart';
import '../widgets/chat/chat_area.dart';
import '../widgets/sidebar/new_desk_dialog.dart';

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

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragStartX == null || _dragStartPage == null) return;
    if (!_pageController.hasClients) return;

    final viewportWidth = _pageController.position.viewportDimension;
    final delta = event.position.dx - _dragStartX!;
    final pageDelta = -delta / viewportWidth;

    final newPage = (_dragStartPage! + pageDelta).clamp(0.0, 1.0);
    _pageController.jumpTo(newPage * viewportWidth);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_dragStartX == null) return;
    if (!_pageController.hasClients) return;

    final delta = event.position.dx - _dragStartX!;
    final viewportWidth = _pageController.position.viewportDimension;

    _dragStartX = null;
    _dragStartPage = null;

    // Determine target page based on position and drag direction
    final currentPosition = _pageController.page ?? _currentPage.toDouble();
    int targetPage;

    if (delta.abs() > viewportWidth * 0.2) {
      // Dragged more than 20% - go to next/prev page
      targetPage = delta > 0 ? 0 : 1;
    } else {
      // Snap to nearest page
      targetPage = currentPosition.round();
    }

    _goToPage(targetPage);
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionAsync.valueOrNull ?? ref.read(relayServiceProvider).isConnected;
    final selectedDesk = ref.watch(selectedDeskProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: NordColors.nord1,
        title: Row(
          children: [
            if (_currentPage == 0) ...[
              const Text(
                'Desks',
                style: TextStyle(fontSize: 18, color: NordColors.nord6),
              ),
            ] else if (selectedDesk != null) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => _goToPage(0),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Text(selectedDesk.deviceIcon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedDesk.deskName,
                  style: const TextStyle(fontSize: 16, color: NordColors.nord5),
                  overflow: TextOverflow.ellipsis,
                ),
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
          // Connection status + pylon icons
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
      ),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (page) => setState(() => _currentPage = page),
          children: [
            // Page 0: Desk list
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
            // Page 1: Chat
            const ChatArea(),
          ],
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
              ...pylon.desks.map((desk) {
                final isSelected = selectedDesk?.deskId == desk.deskId;
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Material(
                    color: isSelected ? NordColors.nord10 : NordColors.nord1,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onDeskSelected(desk),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    desk.deskName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: desk.isWorking
                                          ? NordColors.nord13
                                          : isSelected
                                              ? NordColors.nord6
                                              : NordColors.nord4,
                                    ),
                                  ),
                                  if (desk.workingDir.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      desk.workingDir,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: NordColors.nord3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (desk.isWorking)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: NordColors.nord13,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: NordColors.nord3,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

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
