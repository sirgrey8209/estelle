import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../state/providers/relay_provider.dart';
import '../../state/providers/workspace_provider.dart';
import '../../state/providers/claude_provider.dart';
import '../../data/models/workspace_info.dart';
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
  final _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  double? _dragStartX;
  double? _dragStartPage;

  // Triple tap detection
  int _tapCount = 0;
  DateTime? _lastTapTime;

  static const int _pageCount = 2; // Workspaces, Chat

  @override
  void initState() {
    super.initState();
  }

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
    const deadZone = 0.1;
    const maxZone = 0.4;

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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const Scaffold(
          body: SettingsScreen(),
        ),
      ),
    );
  }

  bool _shouldShowOverlay(LoadingState loadingState) {
    return loadingState == LoadingState.connecting ||
        loadingState == LoadingState.loadingWorkspaces;
  }

  @override
  Widget build(BuildContext context) {
    // 대화 탭 이벤트 시 채팅 탭으로 자동 전환 (같은 대화를 다시 눌러도 이동)
    ref.listen(conversationTapEventProvider, (previous, next) {
      if (next != null && _currentPage == 0) {
        _goToPage(1);
      }
    });

    final connectionAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionAsync.valueOrNull ?? ref.read(relayServiceProvider).isConnected;
    final loadingState = ref.watch(loadingStateProvider);
    final pylonWorkspaces = ref.watch(pylonWorkspacesProvider);
    final selectedItem = ref.watch(selectedItemProvider);
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider);
    final selectedConversation = ref.watch(selectedConversationProvider);

    return Scaffold(
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Column(
              children: [
                // 최상단 바: Estelle / 접속상태 / 설정
                _TopBar(
                  isConnected: isConnected,
                  pylons: pylonWorkspaces.values.toList(),
                  onSettingsTap: _openSettings,
                ),
                // 서브 헤더
                _SubHeader(
                  currentPage: _currentPage,
                  selectedItem: selectedItem,
                  selectedWorkspace: selectedWorkspace,
                  selectedConversation: selectedConversation,
                  onBackTap: () => _goToPage(0),
                ),
                // 콘텐츠 영역
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Loading overlay
            if (_shouldShowOverlay(loadingState))
              Positioned.fill(
                child: LoadingOverlay(state: loadingState),
              ),
          ],
        ),
      ),
    );
  }
}

/// 최상단 바: Estelle / 접속상태+Pylon아이콘 / 설정버튼
class _TopBar extends StatelessWidget {
  final bool isConnected;
  final List<PylonWorkspaces> pylons;
  final VoidCallback onSettingsTap;

  const _TopBar({
    required this.isConnected,
    required this.pylons,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 8,
        bottom: 8,
      ),
      decoration: const BoxDecoration(
        color: NordColors.nord0,
        border: Border(
          bottom: BorderSide(color: NordColors.nord2),
        ),
      ),
      child: Row(
        children: [
          // 로고
          const Text(
            'Estelle',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: NordColors.nord6,
            ),
          ),
          const Spacer(),
          // 접속 상태 + Pylon 아이콘들 (컴팩트: 🏢✓🏠✓ 또는 🏢✗🏠✗ 또는 Offline)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: NordColors.nord1,
              borderRadius: BorderRadius.circular(4),
            ),
            child: isConnected
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: pylons.isNotEmpty
                        ? pylons.map((pylon) {
                            // deviceId에 따른 기본 아이콘
                            final icon = pylon.icon.isNotEmpty
                                ? pylon.icon
                                : (pylon.deviceId == 1 ? '🏢' : pylon.deviceId == 2 ? '🏠' : '💻');
                            return Text(
                              '$icon✓',
                              style: const TextStyle(fontSize: 12),
                            );
                          }).toList()
                        : const [
                            Text('🏢✗🏠✗', style: TextStyle(fontSize: 12)),
                          ],
                  )
                : const Text(
                    'Offline',
                    style: TextStyle(fontSize: 11, color: NordColors.nord11),
                  ),
          ),
          // 설정 버튼
          IconButton(
            icon: const Icon(Icons.settings, color: NordColors.nord4, size: 22),
            onPressed: onSettingsTap,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// 서브 헤더: 워크스페이스 페이지면 "Workspaces", 채팅 페이지면 "← 대화명 + 메뉴"
class _SubHeader extends ConsumerWidget {
  final int currentPage;
  final SelectedItem? selectedItem;
  final WorkspaceInfo? selectedWorkspace;
  final ConversationInfo? selectedConversation;
  final VoidCallback onBackTap;

  const _SubHeader({
    required this.currentPage,
    required this.selectedItem,
    required this.selectedWorkspace,
    required this.selectedConversation,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: NordColors.nord1,
        border: Border(
          bottom: BorderSide(color: NordColors.nord2),
        ),
      ),
      child: currentPage == 0
          ? _buildWorkspaceHeader()
          : _buildChatHeader(context, ref),
    );
  }

  Widget _buildWorkspaceHeader() {
    return const Row(
      children: [
        SizedBox(width: 8),
        Icon(Icons.workspaces, color: NordColors.nord4, size: 20),
        SizedBox(width: 8),
        Text(
          'Workspaces',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: NordColors.nord5,
          ),
        ),
      ],
    );
  }

  Widget _buildChatHeader(BuildContext context, WidgetRef ref) {
    final title = selectedItem?.isTask == true
        ? '📋 태스크'
        : selectedConversation != null
            ? '${selectedConversation!.skillIcon} ${selectedConversation!.name}'
            : '대화를 선택하세요';

    return Row(
      children: [
        // 뒤로가기 버튼
        IconButton(
          icon: const Icon(Icons.arrow_back, color: NordColors.nord4, size: 20),
          onPressed: onBackTap,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 4),
        // 대화명
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: NordColors.nord5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 메뉴 버튼 (대화 선택된 경우만)
        if (selectedConversation != null && selectedWorkspace != null)
          _SessionMenuButton(
            workspace: selectedWorkspace!,
            conversation: selectedConversation!,
          ),
      ],
    );
  }
}

/// 세션 메뉴 버튼 (새 세션, 컴팩트)
class _SessionMenuButton extends ConsumerWidget {
  final WorkspaceInfo workspace;
  final ConversationInfo conversation;

  const _SessionMenuButton({
    required this.workspace,
    required this.conversation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: NordColors.nord4, size: 20),
      color: NordColors.nord1,
      onSelected: (action) => _handleAction(context, ref, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'new_session',
          child: Row(
            children: [
              Icon(Icons.refresh, color: NordColors.nord4, size: 18),
              SizedBox(width: 8),
              Text('새 세션', style: TextStyle(color: NordColors.nord5)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'compact',
          child: Row(
            children: [
              Icon(Icons.compress, color: NordColors.nord4, size: 18),
              SizedBox(width: 8),
              Text('컴팩트', style: TextStyle(color: NordColors.nord5)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'bug_report',
          child: Row(
            children: [
              Icon(Icons.bug_report, color: NordColors.nord4, size: 18),
              SizedBox(width: 8),
              Text('버그 리포트', style: TextStyle(color: NordColors.nord5)),
            ],
          ),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'new_session':
        _showNewSessionDialog(context, ref);
        break;
      case 'compact':
        ref.read(relayServiceProvider).sendClaudeControl(
          workspace.deviceId,
          workspace.workspaceId,
          conversation.conversationId,
          'compact',
        );
        break;
      case 'bug_report':
        BugReportDialog.show(context);
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
                workspace.deviceId,
                workspace.workspaceId,
                conversation.conversationId,
                'new_session',
              );
              ref.read(claudeMessagesProvider.notifier).clearMessages();
              ref.read(claudeMessagesProvider.notifier).clearConversationCache(conversation.conversationId);
              Navigator.pop(context);
            },
            child: const Text('새 세션 시작'),
          ),
        ],
      ),
    );
  }
}
