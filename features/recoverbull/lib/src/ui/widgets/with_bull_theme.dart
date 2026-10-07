import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

extension RecoverBullThemeContext on BuildContext {
  BullTheme get appColors =>
      Theme.of(this).extension<BullTheme>() ??
      fallbackBullTheme(Theme.of(this));

  TextTheme get font => bullText;
}

BullTheme fallbackBullTheme(ThemeData data) {
  final scheme = data.colorScheme;
  return BullTheme(
    primary: scheme.primary,
    onPrimary: scheme.onPrimary,
    primaryFixed: scheme.primary,
    onPrimaryFixed: scheme.onPrimary,
    secondary: scheme.secondary,
    onSecondary: scheme.onSecondary,
    secondaryFixed: scheme.secondary,
    secondaryFixedDim: scheme.outline,
    onSecondaryFixed: scheme.onSecondary,
    tertiary: scheme.tertiary,
    onTertiary: scheme.onTertiary,
    tertiaryContainer: scheme.tertiaryContainer,
    bitcoinOrange: scheme.tertiary,
    background: scheme.surface,
    surface: scheme.surface,
    surfaceContainer: scheme.surfaceContainer,
    surfaceContainerHighest: scheme.surfaceContainerHighest,
    surfaceBright: scheme.surface,
    onSurface: scheme.onSurface,
    onSurfaceVariant: scheme.onSurfaceVariant,
    inverseSurface: scheme.inverseSurface,
    cardBackground: scheme.surface,
    text: scheme.onSurface,
    textMuted: scheme.onSurfaceVariant,
    border: scheme.outline,
    outline: scheme.outline,
    outlineVariant: scheme.outlineVariant,
    error: scheme.error,
    onError: scheme.onError,
    errorContainer: scheme.errorContainer,
    success: scheme.primary,
    warning: scheme.tertiary,
    warningContainer: scheme.tertiaryContainer,
    info: scheme.primary,
    scrim: scheme.scrim,
    overlay: scheme.scrim,
    transparent: Colors.transparent,
    surfaceFixed: scheme.surface,
    onSurfaceFixed: scheme.onSurface,
    shimmerBase: scheme.surfaceContainerHighest,
    shimmerHighlight: scheme.surface,
  );
}

Widget withBullTheme(BuildContext context, Widget child) {
  if (Theme.of(context).extension<BullTheme>() != null) return child;
  return Theme(
    data: Theme.of(
      context,
    ).copyWith(extensions: [fallbackBullTheme(Theme.of(context))]),
    child: child,
  );
}
