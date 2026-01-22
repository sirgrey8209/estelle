import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/utils/responsive_utils.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // URL 파라미터로 모바일 레이아웃 강제 (?mobile=true)
  if (kIsWeb) {
    final uri = Uri.base;
    if (uri.queryParameters['mobile'] == 'true') {
      ResponsiveUtils.forceMobileLayout = true;
    }
  }

  runApp(
    const ProviderScope(
      child: EstelleApp(),
    ),
  );
}
