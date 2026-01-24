import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// 앱 전체에서 사용하는 색상 정의
class AppColors {
  AppColors._();

  // 배경색
  static const Color background = NordColors.nord0;
  static const Color sidebarBg = NordColors.nord1;
  static const Color cardBg = NordColors.nord2;

  // 텍스트
  static const Color textPrimary = NordColors.nord6;
  static const Color textSecondary = NordColors.nord4;
  static const Color textMuted = NordColors.nord3;

  // 강조/액션
  static const Color accent = NordColors.nord8;
  static const Color accentHover = NordColors.nord9;

  // 상태 색상
  static const Color statusError = NordColors.nord11;
  static const Color statusWarning = NordColors.nord13;
  static const Color statusSuccess = NordColors.nord14;
  static const Color statusWorking = NordColors.nord13;

  // 구분선
  static const Color divider = NordColors.nord3;

  // 선택 상태
  static const Color sidebarSelected = NordColors.nord2;
  static const Color sidebarHover = Color(0xFF3B4252);

  // 버튼
  static const Color buttonPrimary = NordColors.nord8;
  static const Color buttonSecondary = NordColors.nord3;
}
