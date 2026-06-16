import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

/// Minimal [BullTheme] for widget tests. A bare `MaterialApp` would crash
/// `context.bull` (the accessor force-unwraps the extension), so every test
/// wraps its widget in this.
const testBullTheme = BullTheme(
  red: Color(0xFFC50909),
  onRed: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  card: Color(0xFFFFFFFF),
  text: Color(0xFF15171C),
  muted: Color(0xFF70747D),
  info: Color(0xFF0063F7),
  success: Color(0xFF34C759),
  warning: Color(0xFFFB9300),
  btc: Color(0xFFF7931A),
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

/// Wraps [child] in a `MaterialApp` carrying [testBullTheme].
Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [testBullTheme]),
    home: Scaffold(body: child),
  );
}
