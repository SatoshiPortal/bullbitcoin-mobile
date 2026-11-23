import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';

ThemeData accessTestTheme(Brightness brightness) {
  final colors = brightness == Brightness.light
      ? testBullTheme
      : testBullTheme.copyWith(
          surface: testBullTheme.inverseSurface,
          text: testBullTheme.onSecondary,
          onSurface: testBullTheme.surface,
        );
  return ThemeData(
    brightness: brightness,
    extensions: bullUiExtensions(
      colors: colors,
      brightness: brightness,
      typography: BullTypography.standard.resolved(colors.text),
    ),
  );
}
