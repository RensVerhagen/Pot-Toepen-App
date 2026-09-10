import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF071B15);
  static const deepGreen = Color(0xFF0C2B21);
  static const felt = Color(0xFF123A2D);
  static const raised = Color(0xFF194638);
  static const cream = Color(0xFFFFF7E7);
  static const mutedCream = Color(0xFFC9D3C9);
  static const gold = Color(0xFFF2B84B);
  static const goldSoft = Color(0xFFFFD98A);
  static const mint = Color(0xFF70D6A7);
  static const coral = Color(0xFFFF806F);
  static const black = Color(0xFF06110D);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.gold,
    onPrimary: AppColors.black,
    secondary: AppColors.mint,
    onSecondary: AppColors.black,
    error: AppColors.coral,
    onError: AppColors.black,
    surface: AppColors.deepGreen,
    onSurface: AppColors.cream,
    surfaceContainerHighest: AppColors.raised,
    outline: Color(0xFF49685C),
    outlineVariant: Color(0xFF284C3F),
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: const TextStyle(
        color: AppColors.cream,
        fontSize: 54,
        height: .96,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.2,
      ),
      displaySmall: const TextStyle(
        color: AppColors.cream,
        fontSize: 36,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineMedium: const TextStyle(
        color: AppColors.cream,
        fontSize: 26,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
      ),
      titleLarge: const TextStyle(
        color: AppColors.cream,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: const TextStyle(
        color: AppColors.cream,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: const TextStyle(
        color: AppColors.cream,
        fontSize: 16,
        height: 1.35,
      ),
      bodyMedium: const TextStyle(
        color: AppColors.mutedCream,
        fontSize: 14,
        height: 1.35,
      ),
      labelLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: .2,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.cream,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 52),
        foregroundColor: AppColors.cream,
        side: const BorderSide(color: Color(0xFF49685C)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.raised.withValues(alpha: .72),
      hintStyle: const TextStyle(color: Color(0xFF82988E)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF315548)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.cream,
      contentTextStyle: const TextStyle(
        color: AppColors.black,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: const Color(0xFF7B5200),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF294C3F), space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.deepGreen,
      modalBackgroundColor: AppColors.deepGreen,
      showDragHandle: true,
      dragHandleColor: Color(0xFF55766A),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.deepGreen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
