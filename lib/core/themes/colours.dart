import 'package:flutter/material.dart';

class AppColours {
  static ColorScheme lightColourScheme = ColorScheme(
    // Primary: Bull Bitcoin red (brand colour)
    primary: const Color(0xFFC50909),
    onPrimary: const Color(0xFFFFFFFF),
    primaryFixed: const Color(0xFFC50909),
    onPrimaryFixed: const Color(0xFFFFFFFF),

    // Secondary: Yellow accent
    secondary: const Color(0xFFFFCC00),
    onSecondary: const Color(0xFF000000),
    secondaryFixed: const Color(0xFFFFF4CC),
    onSecondaryFixed: const Color(0xFF332900),
    secondaryFixedDim: const Color(0xFFFFE599),

    // Tertiary: Orange accent
    tertiary: const Color(0xFFFF9500),
    onTertiary: const Color(0xFF000000),
    tertiaryFixed: const Color(0xFFFFE5CC),
    tertiaryFixedDim: const Color(0xFFFFD1A3),

    // Surface: Backgrounds
    surface: const Color(0xFFF5F5F5),
    onSurface: const Color(0xFF15171C),
    surfaceContainer: const Color(0xFFE6E6E6),
    surfaceContainerLow: const Color(0xFFEFEFEF),
    onSurfaceVariant: const Color(0xFF3E434E),

    // Outline: Borders
    outline: const Color(0xFFD9D9D9),
    outlineVariant: const Color(0xFFE6E6E6),

    // Other colors
    error: const Color(0xFFFF3B30),
    onError: const Color(0xFFFB9300),
    inverseSurface: const Color(0xFF34C759),
    inversePrimary: const Color(0xFF0063F7),
    surfaceDim: const Color(0xFFFFFFFF).withAlpha(_getAlpha(0.25)),
    surfaceBright: const Color(0xFFFFFFFF).withAlpha(_getAlpha(0.5)),
    scrim: const Color(0xFF000000).withAlpha(_getAlpha(0.15)),
    shadow: const Color(0xFF000000).withAlpha(_getAlpha(0.25)),
    brightness: Brightness.light,
  );

  static ColorScheme darkColourScheme = ColorScheme(
    // Primary: Lighter red for dark theme, but fixed remains brand red
    primary: const Color(0xFFFF6B6B),
    onPrimary: const Color(0xFF000000),
    primaryFixed: const Color(0xFFC50909),
    onPrimaryFixed: const Color(0xFFFFFFFF),

    // Secondary: Bright yellow for dark theme
    secondary: const Color(0xFFFFD60A),
    onSecondary: const Color(0xFF000000),
    secondaryFixed: const Color(0xFF664D00),
    onSecondaryFixed: const Color(0xFFFFF4CC),
    secondaryFixedDim: const Color(0xFF4D3900),

    // Tertiary: Orange for dark theme
    tertiary: const Color(0xFFFFAB40),
    onTertiary: const Color(0xFF000000),
    tertiaryFixed: const Color(0xFF663300),
    tertiaryFixedDim: const Color(0xFF4D2600),

    // Surface: Dark backgrounds
    surface: const Color(0xFF1A1C21),
    onSurface: const Color(0xFFE8E9ED),
    surfaceContainer: const Color(0xFF2A2C32),
    surfaceContainerLow: const Color(0xFF1E2025),
    onSurfaceVariant: const Color(0xFFC4C6CF),

    // Outline: Dark borders
    outline: const Color(0xFF44464C),
    outlineVariant: const Color(0xFF3A3C42),

    // Other colors
    error: const Color(0xFFFF453A),
    onError: const Color(0xFF000000),
    inverseSurface: const Color(0xFF34C759),
    inversePrimary: const Color(0xFF0A84FF),
    surfaceDim: const Color(0xFF000000).withAlpha(_getAlpha(0.25)),
    surfaceBright: const Color(0xFFFFFFFF).withAlpha(_getAlpha(0.08)),
    scrim: const Color(0xFF000000).withAlpha(_getAlpha(0.4)),
    shadow: const Color(0xFF000000).withAlpha(_getAlpha(0.5)),
    brightness: Brightness.dark,
  );
}

int _getAlpha(double opacity) => (255 * opacity).toInt();
