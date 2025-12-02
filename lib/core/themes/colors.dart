import 'package:flutter/material.dart';

class AppColors {
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color background;
  final Color surface;
  final Color onSurface;
  final Color cardBackground;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color success;
  final Color warning;
  final Color warningContainer;
  final Color info;

  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.cardBackground,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.success,
    required this.warning,
    required this.warningContainer,
    required this.info,
  });

  static const light = AppColors(
    primary: Color(0xFFC50909),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF15171C),
    onSecondary: Color(0xFFFFFFFF),
    background: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF15171C),
    cardBackground: Color(0xFFFFFFFF),
    text: Color(0xFF15171C),
    textMuted: Color(0xFF70747D),
    border: Color(0xFFC9CACD),
    error: Color(0xFFFF3B30),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFEBEE),
    success: Color(0xFF34C759),
    warning: Color(0xFFFB9300),
    warningContainer: Color(0xFFFFF4E6),
    info: Color(0xFF0063F7),
  );

  static const dark = AppColors(
    primary: Color(0xFFC50909),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF1C1C1E),
    onSecondary: Color(0xFFFFFFFF),
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    onSurface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFF2C2C2E),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFF8E8E93),
    border: Color(0xFF58585A),
    error: Color(0xFFFF453A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFF3D0000),
    success: Color(0xFF32D74B),
    warning: Color(0xFFFF9F0A),
    warningContainer: Color(0xFF3D2D00),
    info: Color(0xFF0A84FF),
  );

  ColorScheme toColorScheme(Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      tertiary: const Color(0xFFFFCC00),
      onTertiary: const Color(0xFFFF9500),
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      surface: surface,
      onSurface: onSurface,
      outline: border,
      primaryFixed: const Color(0xFFC50909),
      onPrimaryFixed: const Color(0xFFFFFFFF),
      secondaryFixed: const Color(0xFF15171C),
      onSecondaryFixed: const Color(0xFFFFFFFF),
      tertiaryContainer: warningContainer,
      surfaceBright: const Color(0xFFFFFFFF).withValues(alpha: 0.5),
      scrim: const Color(0xFF000000).withValues(alpha: 0.15),
    );
  }
}
