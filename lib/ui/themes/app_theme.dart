import 'package:bb_mobile/ui/themes/colours.dart';
import 'package:bb_mobile/ui/themes/fonts.dart';
import 'package:flutter/material.dart';

enum AppThemeType { light, dark }

class AppTheme {
  static ThemeData themeData(AppThemeType themeType) {
    final colours = themeType == AppThemeType.dark
        ? AppColours.darkColourScheme
        : AppColours.lightColourScheme;
    final fonts = AppFonts.textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colours,
      canvasColor: colours.surface,
      scaffoldBackgroundColor: colours.surface,
      fontFamily: fonts.fontFamily,
      textTheme: fonts.textTheme,
    );
  }
}
