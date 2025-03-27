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
      scaffoldBackgroundColor: colours.secondaryFixed,
      fontFamily: fonts.fontFamily,
      textTheme: fonts.textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colours.secondaryFixed,
        // foregroundColor: colours.primary,
        elevation: 0,
        scrolledUnderElevation: 32,

        // shadowColor: colours.secondaryFixed,
      ),
    );
  }
}

extension FontEx on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get font => theme.textTheme;
  ColorScheme get colour => theme.colorScheme;
}

class WidgetStyles {
  static InputDecoration inputDecoration(
    BuildContext context,
    String hintText,
  ) {
    return InputDecoration(
      fillColor: context.colour.onPrimary,
      filled: true,
      hintText: hintText,
      hintStyle: context.font.bodyMedium!.copyWith(
        color: context.colour.surfaceContainer,
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(
          color: context.colour.secondaryFixedDim,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(
          color: context.colour.secondaryFixedDim,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: context.colour.secondaryFixedDim,
          width: 2.0,
        ),
      ),
    );
  }
}
