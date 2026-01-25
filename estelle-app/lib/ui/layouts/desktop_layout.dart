import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/build_info.dart';
import '../../data/models/workspace_info.dart';
import '../../state/providers/relay_provider.dart';
import '../../state/providers/workspace_provider.dart';
import '../widgets/sidebar/workspace_sidebar.dart';
import '../widgets/chat/chat_area.dart';
import '../widgets/task/task_detail_view.dart';
import '../widgets/settings/settings_dialog.dart';
import '../widgets/common/loading_overlay.dart';
import '../widgets/common/bug_report_dialog.dart';

class DesktopLayout extends ConsumerStatefulWidget {
  const DesktopLayout({super.key});

  @override
  ConsumerState<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends ConsumerState<DesktopLayout> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // 백틱(`) 키로 버그 리포트 다이얼로그 열기
      if (event.logicalKey == LogicalKeyboardKey.backquote) {
        BugReportDialog.show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(connectionStateProvider);
    final pylonWorkspaces = ref.watch(pylonWorkspacesProvider);
    final loadingState = ref.watch(loadingStateProvider);
    final selectedItem = ref.watch(selectedItemProvider);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
      children: [
        Scaffold(
          body: Column(
            children: [
              // Header
              _Header(
                isConnected: connectionAsync.valueOrNull ?? ref.read(relayServiceProvider).isConnected,
                pylonWorkspaces: pylonWorkspaces,
              ),

              // Main content
              Expanded(
                child: Row(
                  children: [
                    // Sidebar (Workspace only)
                    const SizedBox(width: 280, child: WorkspaceSidebar()),

                    // Divider
                    const VerticalDivider(width: 1, color: NordColors.nord2),

                    // Main area (대화 또는 태스크)
                    Expanded(
                      child: selectedItem?.isTask == true
                          ? const TaskDetailView()
                          : const ChatArea(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Loading overlay (connecting, loadingWorkspaces, loadingMessages)
        if (loadingState != LoadingState.ready)
          Positioned.fill(
            child: LoadingOverlay(state: loadingState),
          ),
      ],
    ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isConnected;
  final Map<int, PylonWorkspaces> pylonWorkspaces;

  const _Header({
    required this.isConnected,
    required this.pylonWorkspaces,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: NordColors.nord1,
        border: Border(
          bottom: BorderSide(color: NordColors.nord2),
        ),
      ),
      child: Row(
        children: [
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings, color: NordColors.nord4, size: 20),
            onPressed: () => SettingsDialog.show(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 12),
          // Title
          const Text(
            'Estelle Flutter',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: NordColors.nord6,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            BuildInfo.version,
            style: TextStyle(
              fontSize: 12,
              color: NordColors.nord4.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            // buildTime에서 년도 제외 (MMDDHHmmss)
            BuildInfo.buildTime.length >= 14
                ? BuildInfo.buildTime.substring(4)
                : BuildInfo.buildTime,
            style: TextStyle(
              fontSize: 10,
              color: NordColors.nord4.withOpacity(0.5),
            ),
          ),

          const Spacer(),

          // Status
          if (!isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: NordColors.nord2,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Disconnected',
                style: TextStyle(
                  fontSize: 14,
                  color: NordColors.nord11,
                ),
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: NordColors.nord2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 14,
                      color: NordColors.nord14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Connected device icons
                ...pylonWorkspaces.values.map((pylon) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Tooltip(
                      message: pylon.name,
                      child: Text(
                        pylon.icon,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}
