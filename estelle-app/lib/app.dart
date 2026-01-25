import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'state/providers/relay_provider.dart';
import 'state/providers/workspace_provider.dart';
import 'ui/layouts/responsive_layout.dart';

class EstelleApp extends ConsumerStatefulWidget {
  const EstelleApp({super.key});

  @override
  ConsumerState<EstelleApp> createState() => _EstelleAppState();
}

class _EstelleAppState extends ConsumerState<EstelleApp> {
  @override
  void initState() {
    super.initState();
    // Connect to relay on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(relayServiceProvider).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth changes to request workspace list
    ref.listen<AsyncValue<bool>>(authStateProvider, (prev, next) {
      if (next.valueOrNull == true) {
        // 워크스페이스 목록 요청
        ref.read(pylonWorkspacesProvider.notifier).requestWorkspaceList();
      }
    });

    return MaterialApp(
      title: 'Estelle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      home: const ResponsiveLayout(),
    );
  }
}
