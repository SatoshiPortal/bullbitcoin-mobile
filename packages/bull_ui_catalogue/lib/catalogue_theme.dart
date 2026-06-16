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
    red: Color(0xFFC50909),
    onRed: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF15171C),
    muted: Color(0xFF70747D),
    info: Color(0xFF0063F7),
    success: Color(0xFF34C759),
    warning: Color(0xFFFB9300),
    btc: Color(0xFFFF9500),
    outlineVariant: Color(0xFFE8E8E8),
    shimmerBase: Color(0xFFE0E0E0),
    shimmerHighlight: Color(0xFFF5F5F5),
    secondary: Color(0xFF15171C),
    onSecondary: Color(0xFFFFFFFF),
    secondaryFixedDim: Color(0xFFC9CACD),
    border: Color(0xFFC9CACD),
    onSurface: Color(0xFF15171C),
    onSurfaceVariant: Color(0xFF70747D),
    scrim: Color(0x26000000),
  );

  static const BullTheme dark = BullTheme(
    red: Color(0xFFC50909),
    onRed: Color(0xFFFFFFFF),
    surface: Color(0xFF1C1C1E),
    card: Color(0xFF2C2C2E),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF8E8E93),
    info: Color(0xFF0A84FF),
    success: Color(0xFF32D74B),
    warning: Color(0xFFFF9F0A),
    btc: Color(0xFFFF9F0A),
    outlineVariant: Color(0xFF3C3C3E),
    shimmerBase: Color(0xFF3C3C3E),
    shimmerHighlight: Color(0xFF48484A),
    secondary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF15171C),
    secondaryFixedDim: Color(0xFF58585A),
    border: Color(0xFF58585A),
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF8E8E93),
    scrim: Color(0x26000000),
  );
}

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
    extensions: [bull],
    colorScheme: ColorScheme.fromSeed(
      seedColor: bull.red,
      brightness: brightness,
      primary: bull.red,
    ),
    scaffoldBackgroundColor: bull.surface,
    canvasColor: bull.card,
  );
}
