import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';
import 'desktop_layout.dart';
import 'mobile_layout.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key});

  @override
  Widget build(BuildContext context) {
    if (ResponsiveUtils.shouldShowSidebar(context)) {
      return const DesktopLayout();
    }
    return const MobileLayout();
  }
}
