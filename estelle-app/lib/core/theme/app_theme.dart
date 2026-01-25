import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class AppTheme {
  AppTheme._();

  // Noto Color Emoji를 fallback으로 포함한 TextStyle 생성
  static const _fontFallback = ['Noto Color Emoji'];

  static TextStyle _withEmojiFallback(TextStyle style) {
    return style.copyWith(fontFamilyFallback: _fontFallback);
  }

  static ThemeData get darkTheme {
    // Noto Color Emoji 폰트 미리 로드
    GoogleFonts.notoColorEmoji();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NordColors.nord0,
      colorScheme: const ColorScheme.dark(
        primary: NordColors.nord10,
        secondary: NordColors.nord9,
        surface: NordColors.nord1,
        error: NordColors.nord11,
        onPrimary: NordColors.nord6,
        onSecondary: NordColors.nord6,
        onSurface: NordColors.nord4,
        onError: NordColors.nord6,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NordColors.nord1,
        foregroundColor: NordColors.nord6,
        elevation: 0,
      ),
      cardTheme: const CardTheme(
        color: NordColors.nord1,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: NordColors.nord2,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NordColors.nord0,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: NordColors.nord2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: NordColors.nord2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: NordColors.nord9),
        ),
        hintStyle: const TextStyle(color: NordColors.nord3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NordColors.nord10,
          foregroundColor: NordColors.nord6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NordColors.nord9,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(NordColors.nord3),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(8),
      ),
      textTheme: TextTheme(
        bodyLarge: _withEmojiFallback(const TextStyle(color: NordColors.nord4, fontSize: 14)),
        bodyMedium: _withEmojiFallback(const TextStyle(color: NordColors.nord4, fontSize: 13)),
        bodySmall: _withEmojiFallback(const TextStyle(color: NordColors.nord3, fontSize: 12)),
        titleLarge: _withEmojiFallback(const TextStyle(color: NordColors.nord6, fontSize: 20, fontWeight: FontWeight.w600)),
        titleMedium: _withEmojiFallback(const TextStyle(color: NordColors.nord5, fontSize: 16, fontWeight: FontWeight.w600)),
        titleSmall: _withEmojiFallback(const TextStyle(color: NordColors.nord4, fontSize: 14, fontWeight: FontWeight.w600)),
        labelMedium: _withEmojiFallback(const TextStyle(color: NordColors.nord3, fontSize: 12)),
      ),
    );
  }
}
