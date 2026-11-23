import 'package:bb_mobile/core/themes/colors.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

enum AppThemeType { light, dark }

/// Builds the `bull_ui` [BullTheme] colour extension from an [AppColors]
/// palette. `bull_ui` is brightness-agnostic — the app hands it the right
/// palette per brightness, so `AppColors` stays the single source of truth.
BullTheme _bullThemeFrom(AppColors colors) {
  return BullTheme(
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    primaryFixed: colors.primaryFixed,
    onPrimaryFixed: colors.onPrimaryFixed,
    secondary: colors.secondary,
    onSecondary: colors.onSecondary,
    secondaryFixed: colors.secondaryFixed,
    secondaryFixedDim: colors.secondaryFixedDim,
    onSecondaryFixed: colors.onSecondaryFixed,
    tertiary: colors.tertiary,
    onTertiary: colors.onTertiary,
    tertiaryContainer: colors.tertiaryContainer,
    bitcoinOrange: colors.bitcoinOrange,
    background: colors.background,
    surface: colors.surface,
    surfaceContainer: colors.surfaceContainer,
    surfaceContainerHighest: colors.surfaceContainerHighest,
    surfaceBright: colors.surfaceBright,
    onSurface: colors.onSurface,
    onSurfaceVariant: colors.onSurfaceVariant,
    inverseSurface: colors.inverseSurface,
    cardBackground: colors.cardBackground,
    text: colors.text,
    textMuted: colors.textMuted,
    border: colors.border,
    outline: colors.outline,
    outlineVariant: colors.outlineVariant,
    error: colors.error,
    onError: colors.onError,
    errorContainer: colors.errorContainer,
    success: colors.success,
    warning: colors.warning,
    warningContainer: colors.warningContainer,
    info: colors.info,
    scrim: colors.scrim,
    overlay: colors.overlay,
    transparent: colors.transparent,
    surfaceFixed: colors.surfaceFixed,
    onSurfaceFixed: colors.onSurfaceFixed,
    shimmerBase: colors.shimmerBase,
    shimmerHighlight: colors.shimmerHighlight,
  );
}

class AppTheme {
  static const shapes = BullShapes.standard;
  static const typography = BullTypography.standard;

  static ThemeData themeData(AppThemeType themeType) {
    final colors = themeType == AppThemeType.dark
        ? AppColors.dark
        : AppColors.light;
    final brightness = themeType == AppThemeType.dark
        ? Brightness.dark
        : Brightness.light;

    final bullTheme = _bullThemeFrom(colors);
    final typography = AppTheme.typography.resolved(colors.text);

    return ThemeData(
      useMaterial3: true,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.3),
        selectionHandleColor: colors.primary,
      ),
      brightness: brightness,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: brightness == Brightness.light
            ? colors.background
            : colors.surface,
        modalBackgroundColor: brightness == Brightness.light
            ? colors.background
            : colors.surface,
        modalBarrierColor: colors.scrim.withValues(
          alpha: brightness == Brightness.light ? 0.45 : 0.60,
        ),
        constraints: const BoxConstraints(minWidth: double.infinity),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(shapes.sheet),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        modalElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        barrierColor: colors.scrim.withValues(
          alpha: brightness == Brightness.light ? 0.45 : 0.60,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surface,
        border: WidgetStateInputBorder.resolveWith(
          (states) => OutlineInputBorder(
            borderRadius: BorderRadius.circular(shapes.input),
            borderSide: BorderSide(
              color: states.contains(WidgetState.error)
                  ? colors.error
                  : colors.border,
            ),
          ),
        ),
      ),
      extensions: bullUiExtensions(
        colors: bullTheme,
        brightness: brightness,
        shapes: shapes,
        typography: typography,
      ),
      // Material widgets read Bull's colours, so nothing is derived from the red seed. Roles without a Bull colour use the nearest one.
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: brightness,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        primaryContainer: colors.primary.withValues(alpha: 0.12),
        onPrimaryContainer: colors.primary,
        primaryFixed: colors.primaryFixed,
        onPrimaryFixed: colors.onPrimaryFixed,
        inversePrimary: colors.primary,
        secondary: colors.secondary,
        onSecondary: colors.onSecondary,
        secondaryContainer: colors.surfaceContainerHighest,
        onSecondaryContainer: colors.onSurface,
        secondaryFixed: colors.secondaryFixed,
        secondaryFixedDim: colors.secondaryFixedDim,
        onSecondaryFixed: colors.onSecondaryFixed,
        tertiary: colors.tertiary,
        onTertiary: colors.onTertiary,
        tertiaryContainer: colors.tertiaryContainer,
        onTertiaryContainer: colors.onTertiary,
        error: colors.error,
        onError: colors.onError,
        errorContainer: colors.errorContainer,
        onErrorContainer: colors.error,
        surface: colors.surface,
        onSurface: colors.onSurface,
        surfaceDim: colors.background,
        surfaceBright: colors.surfaceBright,
        surfaceContainerLowest: colors.surface,
        surfaceContainerLow: colors.surface,
        surfaceContainer: colors.surfaceContainer,
        surfaceContainerHigh: colors.cardBackground,
        surfaceContainerHighest: colors.surfaceContainerHighest,
        onSurfaceVariant: colors.onSurfaceVariant,
        inverseSurface: colors.inverseSurface,
        onInverseSurface: colors.surface,
        outline: colors.outline,
        outlineVariant: colors.outlineVariant,
        scrim: colors.scrim,
        surfaceTint: colors.transparent,
      ),
      canvasColor: colors.cardBackground,
      scaffoldBackgroundColor: colors.background,
      fontFamily: typography.body.fontFamily,
      textTheme: typography.toTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.transparent,
        // A transparent status bar shows each page's own colour behind it;
        // without it Android paints a grey scrim over light pages.
        systemOverlayStyle:
            (themeType == AppThemeType.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: colors.transparent),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: typography.subtitle.copyWith(color: colors.text),
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.text),
        actionsIconTheme: IconThemeData(color: colors.text),
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
          borderRadius: BorderRadius.circular(shapes.card),
          side: BorderSide(color: colors.border),
        ),
        elevation: 0,
        shadowColor: colors.border,
        margin: EdgeInsets.zero,
      ),
      switchTheme: BullSwitch.themeData(bullTheme),
      listTileTheme: ListTileThemeData(
        tileColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.card),
          side: BorderSide(color: colors.border),
        ),
        textColor: colors.text,
        titleTextStyle: typography.subtitle.copyWith(fontWeight: .w400),
        subtitleTextStyle: typography.caption.copyWith(color: colors.textMuted),
        leadingAndTrailingTextStyle: typography.label.copyWith(
          color: colors.text,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        refreshBackgroundColor: colors.text,
        color: colors.primary,
        circularTrackColor: colors.primary,
        linearTrackColor: colors.surface,
      ),
    );
  }
}

extension ThemeEx on BuildContext {
  ThemeData get theme => Theme.of(this);
  AppColors get appColors =>
      theme.brightness == .dark ? AppColors.dark : AppColors.light;
}

class WidgetStyles {
  static InputDecoration inputDecoration(
    BuildContext context,
    String hintText,
  ) {
    final shapes = context.bullShapes;
    return InputDecoration(
      fillColor: context.appColors.surface,
      filled: true,
      hintText: hintText,
      hintStyle: context.bullType.body.copyWith(
        color: context.appColors.textMuted,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(shapes.input),
        borderSide: BorderSide(color: context.appColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(shapes.input),
        borderSide: BorderSide(color: context.appColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(shapes.input),
        borderSide: BorderSide(color: context.appColors.border, width: 2.0),
      ),
    );
  }
}
