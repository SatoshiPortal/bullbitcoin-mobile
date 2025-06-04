import 'package:bb_mobile/ui/themes/colours.dart';
import 'package:bb_mobile/ui/themes/fonts.dart';
import 'package:flutter/material.dart';

enum AppThemeType { light, dark }

class AppTheme {
  static ThemeData themeData(AppThemeType themeType) {
    final colours =
        themeType == AppThemeType.dark
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
      /* TODO: Add theme for inputs like TextField here and remove BBInputText
       Make sure to check impact on all different inputs in the app and adjust accordingly.
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: fonts.textTheme.bodyLarge?.copyWith(
          color: colours.surfaceContainer,
        ),
        filled: true,
        fillColor: colours.onPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: colours.surface),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: colours.surface),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: colours.surface),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: colours.surface),
        ),
      ),
       */
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        // foregroundColor: colours.primary,
        elevation: 0,
        scrolledUnderElevation: 32,
        titleTextStyle: fonts.textTheme.headlineMedium!.copyWith(
          color: colours.secondary,
        ),
        centerTitle: true,
        // shadowColor: colours.secondaryFixed,
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(Icons.arrow_back),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colours.onPrimary,
        selectedIconTheme: IconThemeData(color: colours.primary),
        unselectedIconTheme: IconThemeData(color: colours.outline),
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
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: context.colour.secondaryFixedDim),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: context.colour.secondaryFixedDim),
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
