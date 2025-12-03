import 'package:bb_mobile/core/themes/colors.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppThemeType { light, dark }

class AppTheme {
  static ThemeData themeData(AppThemeType themeType) {
    final colors =
        themeType == AppThemeType.dark ? AppColors.dark : AppColors.light;
    final brightness =
        themeType == AppThemeType.dark ? Brightness.dark : Brightness.light;
    final fonts = AppFonts.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      canvasColor: colors.cardBackground,
      scaffoldBackgroundColor: colors.background,
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
        backgroundColor: colors.transparent,
        systemOverlayStyle:
            themeType == AppThemeType.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: fonts.textTheme.headlineMedium!.copyWith(
          color: colors.text,
        ),
        centerTitle: true,
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(Icons.arrow_back),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedIconTheme: IconThemeData(color: colors.primary),
        unselectedIconTheme: IconThemeData(color: colors.textMuted),
        selectedLabelStyle: TextStyle(color: colors.primary),
        unselectedLabelStyle: TextStyle(color: colors.textMuted),
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textMuted,
      ),
      cardTheme: CardThemeData(
        color: colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: colors.border),
        ),
        elevation: 0,
        shadowColor: colors.border,
        margin: EdgeInsets.zero,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.text;
          }
          return colors.textMuted;
        }),
        trackOutlineWidth: const WidgetStatePropertyAll(0),
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          return colors.surface;
        }),
        padding: EdgeInsets.zero,
        overlayColor: WidgetStateProperty.all(colors.transparent),
        trackOutlineColor: WidgetStateProperty.all(colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbIcon: WidgetStateProperty.all(
          Icon(Icons.circle, color: colors.surface),
        ),
        splashRadius: 0,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: colors.border),
        ),
        textColor: colors.text,
        titleTextStyle: fonts.textTheme.headlineSmall!.copyWith(
          fontWeight: FontWeight.w400,
        ),
        subtitleTextStyle: fonts.textTheme.labelMedium!.copyWith(
          color: colors.textMuted,
          fontWeight: FontWeight.w400,
        ),
        leadingAndTrailingTextStyle: fonts.textTheme.labelLarge!.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w500,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        refreshBackgroundColor: colors.text,
      ),
    );
  }
}

extension ThemeEx on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get font => theme.textTheme;
  AppColors get appColors =>
      theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;
}

class WidgetStyles {
  static InputDecoration inputDecoration(
    BuildContext context,
    String hintText,
  ) {
    return InputDecoration(
      fillColor: context.appColors.surface,
      filled: true,
      hintText: hintText,
      hintStyle: context.font.bodyMedium!.copyWith(
        color: context.appColors.textMuted,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: context.appColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: context.appColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.appColors.border, width: 2.0),
      ),
    );
  }
}
