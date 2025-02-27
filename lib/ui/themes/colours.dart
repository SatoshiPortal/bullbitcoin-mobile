import 'package:flutter/material.dart';

class AppColours {
  static ColorScheme lightColourScheme = ColorScheme(
    primary: const Color(0xFFC50909),
    secondary: const Color(0xFF15171C),
    onPrimary: const Color(0xFFFFFFFF),
    error: const Color(0xFFFF3B30),
    onError: const Color(0xFFFB9300),
    inverseSurface: const Color(0xFF34C759),
    inversePrimary: const Color(0xFF0063F7),
    surface: const Color(0xFFC9CACD),
    surfaceContainer: const Color(0xFF9C9FA5),
    outline: const Color(0xFF70747D),
    outlineVariant: const Color(0xFF444955),
    onSurfaceVariant: const Color(0xFF3E434E),
    surfaceContainerLow: const Color(0xFF22252B),
    onSurface: const Color(0xFF111215),
    tertiary: const Color(0xFFFFCC00),
    onTertiary: const Color(0xFFFF9500),
    surfaceDim: const Color(0xFFFFFFFF).withAlpha(_getAlpha(0.25)),
    surfaceBright: const Color(0xFFFFFFFF).withAlpha(_getAlpha(0.5)),
    scrim: const Color(0xFF000000).withAlpha(_getAlpha(0.15)),
    shadow: const Color(0xFF000000).withAlpha(_getAlpha(0.25)),
    tertiaryFixed: const Color(0xFF000000).withAlpha(_getAlpha(0.5)),
    tertiaryFixedDim: const Color(0xFF000000).withAlpha(_getAlpha(0.75)),
    secondaryFixed: const Color(0xFFF5F5F5),
    secondaryFixedDim: const Color(0xFFE6E6E6),
    onSecondaryFixed: const Color(0xFFD9D9D9),
    brightness: Brightness.light,
    onSecondary: const Color(0xFFFFFFFF),
  );

  static ColorScheme darkColourScheme = const ColorScheme(
    primary: Color(0xFFC50909),
    secondary: Color(0xFF15171C),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFFFF3B30),
    onError: Color(0xFFFB9300),
    surface: Color(0xFFC9CACD),
    onSurface: Color(0xFF111215),
    brightness: Brightness.dark,
  );
}

int _getAlpha(double opacity) => (255 * opacity).toInt();
