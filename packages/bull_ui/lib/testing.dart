import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Minimal [BullTheme] for widget tests. A bare `MaterialApp` would crash
/// `context.bull` (the accessor force-unwraps the extension), so every test
/// wraps its widget in this.
const testBullTheme = BullTheme(
  primary: Color(0xFFC50909),
  onPrimary: Color(0xFFFFFFFF),
  primaryFixed: Color(0xFFC50909),
  onPrimaryFixed: Color(0xFFFFFFFF),
  secondary: Color(0xFF000000),
  onSecondary: Color(0xFFFFFFFF),
  secondaryFixed: Color(0xFF000000),
  secondaryFixedDim: Color(0xFFC9CACD),
  onSecondaryFixed: Color(0xFFFFFFFF),
  tertiary: Color(0xFFFFCC00),
  onTertiary: Color(0xFFFF9500),
  tertiaryContainer: Color(0xFFFFF4E6),
  bitcoinOrange: Color(0xFFF7931A),
  background: Color(0xFFFFFFFF),
  surface: Color(0xFFF5F5F5),
  surfaceContainer: Color(0xFFE8E8E8),
  surfaceContainerHighest: Color(0xFFDCDCDC),
  surfaceBright: Color(0xFFFFFFFF),
  onSurface: Color(0xFF000000),
  onSurfaceVariant: Color(0xFF70747D),
  inverseSurface: Color(0xFF000000),
  cardBackground: Color(0xFFF5F5F5),
  text: Color(0xFF000000),
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
  surfaceFixed: Color(0xFFF5F5F5),
  onSurfaceFixed: Color(0xFF000000),
  graphiteFixed: Color(0xFF15171C),
  markFixed: Color(0xFFB7000B),
  shimmerBase: Color(0xFFE0E0E0),
  shimmerHighlight: Color(0xFFF5F5F5),
);

/// The resolved type scale used by the test theme and its Material projection.
final testBullTypography = BullTypography.standard.resolved(testBullTheme.text);

/// Every theme extension `bull_ui` components read, for tests that build their
/// own `ThemeData`: `ThemeData(extensions: testBullExtensions)`.
final testBullExtensions = bullUiExtensions(
  colors: testBullTheme,
  brightness: Brightness.light,
  typography: testBullTypography,
);

/// Wraps [child] in a `MaterialApp` carrying [testBullExtensions].
Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: testBullTheme.primary,
        selectionHandleColor: testBullTheme.primary,
        selectionColor: testBullTheme.primary.withValues(alpha: 0.3),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: testBullTheme.background,
        modalBackgroundColor: testBullTheme.background,
        modalBarrierColor: testBullTheme.scrim.withValues(alpha: 0.45),
        constraints: const BoxConstraints(minWidth: double.infinity),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BullShapes.standard.sheet),
          ),
        ),
        elevation: 0,
        modalElevation: 0,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: testBullTheme.surface,
        border: WidgetStateInputBorder.resolveWith(
          (states) => OutlineInputBorder(
            borderRadius: BorderRadius.circular(BullShapes.standard.input),
            borderSide: BorderSide(
              color: states.contains(WidgetState.error)
                  ? testBullTheme.error
                  : testBullTheme.border,
            ),
          ),
        ),
      ),
      extensions: testBullExtensions,
      textTheme: testBullTypography.toTextTheme(),
    ),
    localizationsDelegates: bullUiLocalizationsDelegates,
    supportedLocales: BullUiLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}
