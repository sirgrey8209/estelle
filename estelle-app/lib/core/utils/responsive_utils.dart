import 'package:flutter/material.dart';

class ResponsiveUtils {
  ResponsiveUtils._();

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double sidebarWidth = 260;

  /// 모바일 레이아웃 강제 (테스트용)
  static bool forceMobileLayout = false;

  static bool isMobile(BuildContext context) {
    if (forceMobileLayout) return true;
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    if (forceMobileLayout) return false;
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    if (forceMobileLayout) return false;
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static bool shouldShowSidebar(BuildContext context) {
    if (forceMobileLayout) return false;
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }
}
