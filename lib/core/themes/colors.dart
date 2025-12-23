import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  final Color primary;
  final Color onPrimary;
  final Color primaryFixed;
  final Color onPrimaryFixed;

  // Secondary colors
  final Color secondary;
  final Color onSecondary;
  final Color secondaryFixed;
  final Color secondaryFixedDim;
  final Color onSecondaryFixed;

  // Tertiary colors (accent)
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;

  // Surface colors
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHighest;
  final Color surfaceBright;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color inverseSurface;
  final Color cardBackground;

  // Text colors
  final Color text;
  final Color textMuted;

  // Border colors
  final Color border;
  final Color outline;
  final Color outlineVariant;

  // Status colors
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color success;
  final Color warning;
  final Color warningContainer;
  final Color info;

  // Overlay colors
  final Color scrim;
  final Color overlay;

  // Fixed colors (same in both themes)
  final Color transparent;
  final Color surfaceFixed;
  final Color onSurfaceFixed;

  // Shimmer/loading colors
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryFixed,
    required this.onPrimaryFixed,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryFixed,
    required this.secondaryFixedDim,
    required this.onSecondaryFixed,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHighest,
    required this.surfaceBright,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.inverseSurface,
    required this.cardBackground,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.success,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.scrim,
    required this.overlay,
    required this.transparent,
    required this.surfaceFixed,
    required this.onSurfaceFixed,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const light = AppColors(
    primary: Color(0xFFC50909),
    onPrimary: Color(0xFFFFFFFF),
    primaryFixed: Color(0xFFC50909),
    onPrimaryFixed: Color(0xFFFFFFFF),
    secondary: Color(0xFF15171C),
    onSecondary: Color(0xFFFFFFFF),
    secondaryFixed: Color(0xFF15171C),
    secondaryFixedDim: Color(0xFFC9CACD),
    onSecondaryFixed: Color(0xFFFFFFFF),
    tertiary: Color(0xFFFFCC00),
    onTertiary: Color(0xFFFF9500),
    tertiaryContainer: Color(0xFFFFF4E6),
    background: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF5F5F5),
    surfaceContainerHighest: Color(0xFFE8E8E8),
    surfaceBright: Color(0xFFFFFFFF),
    onSurface: Color(0xFF15171C),
    onSurfaceVariant: Color(0xFF70747D),
    inverseSurface: Color(0xFF15171C),
    cardBackground: Color(0xFFFFFFFF),
    text: Color(0xFF15171C),
    textMuted: Color(0xFF70747D),
    border: Color(0xFFC9CACD),
    outline: Color(0xFFC9CACD),
    outlineVariant: Color(0xFFE8E8E8),
    error: Color(0xFFFF3B30),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFEBEE),
    success: Color(0xFF34C759),
    warning: Color(0xFFFB9300),
    warningContainer: Color(0xFFFFF4E6),
    info: Color(0xFF0063F7),
    scrim: Color(0x26000000),
    overlay: Color(0x80000000),
    transparent: Color(0x00000000),
    surfaceFixed: Color(0xFFFFFFFF),
    onSurfaceFixed: Color(0xFF15171C),
    shimmerBase: Color(0xFFE0E0E0),
    shimmerHighlight: Color(0xFFF5F5F5),
  );

  static const dark = AppColors(
    primary: Color(0xFFC50909),
    onPrimary: Color(0xFFFFFFFF),
    primaryFixed: Color(0xFFC50909),
    onPrimaryFixed: Color(0xFFFFFFFF),
    secondary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF15171C),
    secondaryFixed: Color(0xFF15171C),
    secondaryFixedDim: Color(0xFF58585A),
    onSecondaryFixed: Color(0xFFFFFFFF),
    tertiary: Color(0xFFFFCC00),
    onTertiary: Color(0xFFFF9F0A),
    tertiaryContainer: Color(0xFF3D2D00),
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceContainer: Color(0xFF2C2C2E),
    surfaceContainerHighest: Color(0xFF3C3C3E),
    surfaceBright: Color(0xFF48484A),
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF8E8E93),
    inverseSurface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFF2C2C2E),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFF8E8E93),
    border: Color(0xFF58585A),
    outline: Color(0xFF58585A),
    outlineVariant: Color(0xFF3C3C3E),
    error: Color(0xFFFF453A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFF3D0000),
    success: Color(0xFF32D74B),
    warning: Color(0xFFFF9F0A),
    warningContainer: Color(0xFF3D2D00),
    info: Color(0xFF0A84FF),
    scrim: Color(0x26000000),
    overlay: Color(0x80000000),
    transparent: Color(0x00000000),
    surfaceFixed: Color(0xFFFFFFFF),
    onSurfaceFixed: Color(0xFF15171C),
    shimmerBase: Color(0xFF3C3C3E),
    shimmerHighlight: Color(0xFF48484A),
  );
}
