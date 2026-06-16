import 'package:bb_mobile/core/themes/colors.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppThemeType { light, dark }

/// Builds the `bull_ui` [BullTheme] colour extension from an [AppColors]
/// palette. `bull_ui` is brightness-agnostic — the app hands it the right
/// palette per brightness, so `AppColors` stays the single source of truth.
BullTheme _bullThemeFrom(AppColors colors) {
  return BullTheme(
    red: colors.primary,
    onRed: colors.onPrimary,
    surface: colors.surface,
    card: colors.cardBackground,
    text: colors.text,
    muted: colors.textMuted,
    info: colors.info,
    success: colors.success,
    warning: colors.warning,
    btc: colors.onTertiary,
    outlineVariant: colors.outlineVariant,
    shimmerBase: colors.shimmerBase,
    shimmerHighlight: colors.shimmerHighlight,
    secondary: colors.secondary,
    onSecondary: colors.onSecondary,
    secondaryFixedDim: colors.secondaryFixedDim,
    border: colors.border,
    onSurface: colors.onSurface,
    onSurfaceVariant: colors.onSurfaceVariant,
    scrim: colors.scrim,
  );
}

class AppTheme {
  static ThemeData themeData(AppThemeType themeType) {
    final colors = themeType == AppThemeType.dark
        ? AppColors.dark
        : AppColors.light;
    final brightness = themeType == AppThemeType.dark
        ? Brightness.dark
        : Brightness.light;
    final fonts = AppFonts.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [_bullThemeFrom(colors)],
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: brightness,
        primary: colors.primary,
      ),
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
        systemOverlayStyle: themeType == AppThemeType.dark
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
        backgroundColor: colors.background,
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
        materialTapTargetSize: .shrinkWrap,
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
          fontWeight: .w400,
        ),
        subtitleTextStyle: fonts.textTheme.labelMedium!.copyWith(
          color: colors.textMuted,
          fontWeight: .w400,
        ),
        leadingAndTrailingTextStyle: fonts.textTheme.labelLarge!.copyWith(
          color: colors.text,
          fontWeight: .w500,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        refreshBackgroundColor: colors.text,
        color: colors.primary,
        circularTrackColor: colors.primary,
        linearTrackColor: colors.primary,
      ),
    );
  }
}

extension ThemeEx on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get font => theme.textTheme;
  AppColors get appColors =>
      theme.brightness == .dark ? AppColors.dark : AppColors.light;
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
