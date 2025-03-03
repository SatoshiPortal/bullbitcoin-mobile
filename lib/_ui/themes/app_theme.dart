import 'package:bb_mobile/_ui/themes/colours.dart';
import 'package:bb_mobile/_ui/themes/fonts.dart';
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
      scaffoldBackgroundColor: colours.secondaryFixed,
      fontFamily: fonts.fontFamily,
      textTheme: fonts.textTheme,
    );
  }
}

extension FontEx on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get font => theme.textTheme;
  ColorScheme get colour => theme.colorScheme;
}
