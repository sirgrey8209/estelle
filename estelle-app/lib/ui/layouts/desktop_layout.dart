import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/build_info.dart';
import '../../data/models/desk_info.dart';
import '../../state/providers/relay_provider.dart';
import '../../state/providers/desk_provider.dart';
import '../widgets/sidebar/sidebar.dart';
import '../widgets/chat/chat_area.dart';
import '../widgets/settings/settings_dialog.dart';
import '../widgets/common/loading_overlay.dart';

class DesktopLayout extends ConsumerWidget {
  const DesktopLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStateProvider);
    final pylons = ref.watch(pylonDesksProvider);
    final loadingState = ref.watch(loadingStateProvider);

    return Stack(
      children: [
        Scaffold(
          body: Column(
            children: [
              // Header
              _Header(
                isConnected: connectionAsync.valueOrNull ?? ref.read(relayServiceProvider).isConnected,
                pylons: pylons,
              ),

              // Main content
              Expanded(
                child: Row(
                  children: [
                    // Sidebar
                    const Sidebar(),

                    // Divider
                    const VerticalDivider(width: 1, color: NordColors.nord2),

                    // Chat area
                    const Expanded(child: ChatArea()),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Loading overlay (connecting, loadingDesks, loadingMessages)
        if (loadingState != LoadingState.ready)
          Positioned.fill(
            child: LoadingOverlay(state: loadingState),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final bool isConnected;
  final Map<int, PylonInfo> pylons;

  const _Header({
    required this.isConnected,
    required this.pylons,
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
                ...pylons.values.map((pylon) {
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
