import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

/// Catalogue-local sample palettes for the theme addon.
///
/// `bull_ui` is intentionally brightness-agnostic and literal-free: in the real
/// app the [BullTheme] values are injected from `AppColors` (which lives in the
/// app and which this package must NOT import). To render the components with
/// the right fidelity in the catalogue we keep a small *representative* copy of
/// the app palette here. Literals are acceptable in this dev-only catalogue —
/// they keep `bull_ui` itself free of any colour values.
///
/// These mirror `lib/core/themes/colors.dart` closely enough for visual review;
/// they are not the single source of truth and may drift slightly.
class CatalogueColors {
  const CatalogueColors._();

  static const BullTheme light = BullTheme(
    primary: Color(0xFFC50909),
    onPrimary: Color(0xFFFFFFFF),
    primaryFixed: Color(0xFFC50909),
    onPrimaryFixed: Color(0xFFFFFFFF),
    secondary: Color(0xFF15171C),
    onSecondary: Color(0xFFFFFFFF),
    secondaryFixed: Color(0xFF15171C),
    secondaryFixedDim: Color(0xFFC9CACD),
    onSecondaryFixed: Color(0xFFFFFFFF),
    tertiary: Color(0xFFFFCC00),
    onTertiary: Color(0xFFFF9500),
    tertiaryContainer: Color(0xFFFFF4E6),
    bitcoinOrange: Color(0xFFF7931A),
    background: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF5F5F5),
    surfaceContainerHighest: Color(0xFFE8E8E8),
    surfaceBright: Color(0xFFFFFFFF),
    onSurface: Color(0xFF15171C),
    onSurfaceVariant: Color(0xFF70747D),
    inverseSurface: Color(0xFF15171C),
    cardBackground: Color(0xFFFFFFFF),
    text: Color(0xFF15171C),
    textMuted: Color(0xFF70747D),
    border: Color(0xFFC9CACD),
    outline: Color(0xFFC9CACD),
    outlineVariant: Color(0xFFE8E8E8),
    error: Color(0xFFFF3B30),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFEBEE),
    success: Color(0xFF34C759),
    warning: Color(0xFFFB9300),
    warningContainer: Color(0xFFFFF4E6),
    info: Color(0xFF0063F7),
    scrim: Color(0x26000000),
    overlay: Color(0x80000000),
    transparent: Color(0x00000000),
    surfaceFixed: Color(0xFFFFFFFF),
    onSurfaceFixed: Color(0xFF15171C),
    shimmerBase: Color(0xFFE0E0E0),
    shimmerHighlight: Color(0xFFF5F5F5),
  );

  static const BullTheme dark = BullTheme(
    primary: Color(0xFFC50909),
    onPrimary: Color(0xFFFFFFFF),
    primaryFixed: Color(0xFFC50909),
    onPrimaryFixed: Color(0xFFFFFFFF),
    secondary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF15171C),
    secondaryFixed: Color(0xFF15171C),
    secondaryFixedDim: Color(0xFF58585A),
    onSecondaryFixed: Color(0xFFFFFFFF),
    tertiary: Color(0xFFFFCC00),
    onTertiary: Color(0xFFFF9F0A),
    tertiaryContainer: Color(0xFF3D2D00),
    bitcoinOrange: Color(0xFFF7931A),
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceContainer: Color(0xFF2C2C2E),
    surfaceContainerHighest: Color(0xFF3C3C3E),
    surfaceBright: Color(0xFF48484A),
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF8E8E93),
    inverseSurface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFF2C2C2E),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFF8E8E93),
    border: Color(0xFF58585A),
    outline: Color(0xFF58585A),
    outlineVariant: Color(0xFF3C3C3E),
    error: Color(0xFFFF453A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFF3D0000),
    success: Color(0xFF32D74B),
    warning: Color(0xFFFF9F0A),
    warningContainer: Color(0xFF3D2D00),
    info: Color(0xFF0A84FF),
    scrim: Color(0x26000000),
    overlay: Color(0x80000000),
    transparent: Color(0x00000000),
    surfaceFixed: Color(0xFFFFFFFF),
    onSurfaceFixed: Color(0xFF15171C),
    shimmerBase: Color(0xFF3C3C3E),
    shimmerHighlight: Color(0xFF48484A),
  );
}

/// Catalogue-local Golos-Text [TextTheme], mirroring the app's `AppFonts`
/// roles so the catalogue renders type at the right sizes/weights. Components
/// read roles via `Theme.of(context).textTheme`, so this is what matters.
const TextTheme _catalogueTextTheme = TextTheme(
  displayLarge: TextStyle(fontSize: 46, fontWeight: FontWeight.w500),
  displayMedium: TextStyle(fontSize: 43, fontWeight: FontWeight.w500),
  displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
  headlineLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  headlineMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  headlineSmall: TextStyle(fontSize: 16),
  bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  bodyMedium: TextStyle(fontSize: 14),
  bodySmall: TextStyle(fontSize: 14),
  labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  labelMedium: TextStyle(fontSize: 12),
  labelSmall: TextStyle(fontSize: 10),
);

/// Builds a Material [ThemeData] carrying the [BullTheme] extension, matching
/// how the app wires `bull_ui` (extension on `ThemeData.extensions`). Components
/// read their colours via `context.bull`, so the extension is what matters.
ThemeData catalogueThemeData(Brightness brightness) {
  final bull = brightness == Brightness.dark
      ? CatalogueColors.dark
      : CatalogueColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Golos Text',
    textTheme: _catalogueTextTheme,
    extensions: [bull],
    colorScheme: ColorScheme.fromSeed(
      seedColor: bull.primary,
      brightness: brightness,
      primary: bull.primary,
    ),
    scaffoldBackgroundColor: bull.surface,
    canvasColor: bull.cardBackground,
  );
}
