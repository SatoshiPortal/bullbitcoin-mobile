import 'package:bb_mobile/core/themes/colours.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
       + do the same for other widgets like dropdowns, buttons, etc.
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
        systemOverlayStyle:
            themeType == AppThemeType.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
        elevation: 0,
        scrolledUnderElevation: 32,
        titleTextStyle: fonts.textTheme.headlineMedium!.copyWith(
          color: colours.secondary,
        ),
        centerTitle: true,
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(Icons.arrow_back),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colours.onPrimary,
        selectedIconTheme: IconThemeData(color: colours.primary),
        unselectedIconTheme: IconThemeData(color: colours.outline),
      ),
      cardTheme: CardThemeData(
        color: colours.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: colours.surface),
        ),
        elevation: 0,
        shadowColor: colours.surface,
        margin: EdgeInsets.zero,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colours.secondary; // Active background
          }
          return colours.surfaceContainer; // Inactive background
        }),
        trackOutlineWidth: const WidgetStatePropertyAll(0), // no border
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          return colours.onPrimary; // Thumb is always white
        }),
        padding: EdgeInsets.zero,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        trackOutlineColor: WidgetStateProperty.all(
          Colors.transparent,
        ), // no border
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbIcon: WidgetStateProperty.all(
          Icon(Icons.circle, color: colours.onPrimary),
        ),
        splashRadius: 0,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: colours.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: colours.surface),
        ),
        textColor: colours.secondary,
        titleTextStyle: fonts.textTheme.headlineSmall!.copyWith(
          fontWeight: FontWeight.w400,
        ),
        subtitleTextStyle: fonts.textTheme.labelMedium!.copyWith(
          color: colours.outline,
          fontWeight: FontWeight.w400,
        ),
        leadingAndTrailingTextStyle: fonts.textTheme.labelLarge!.copyWith(
          color: colours.secondary,
          fontWeight: FontWeight.w500,
        ),
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
