import 'package:flutter/material.dart';

class AppColours {
  static const _black = Colors.black;
  static const _white = Colors.white;
  static const _brandRed = Color(0xFFC50909);
  static const _brandYellow = Color(0xFFE8B931);
  static const _bgWhite = Color(0xFFF5F5F5);
  static const _darkGray = Color(0xFF1C1B1F);
  static const _lightGray = Color(0xFFF6F6F6);

  static ColorScheme lightColourScheme = const ColorScheme(
    primary: _brandRed,
    secondary: _brandYellow,
    surface: _bgWhite,
    error: _black,
    onPrimary: _white,
    onSecondary: _black,
    onSurface: _darkGray,
    onError: _white,
    brightness: Brightness.light,
  );

  static ColorScheme darkColourScheme = const ColorScheme(
    primary: _brandRed,
    secondary: _brandYellow,
    surface: _darkGray,
    error: _black,
    onPrimary: _white,
    onSecondary: _black,
    onSurface: _lightGray,
    onError: _white,
    brightness: Brightness.dark,
  );
}
