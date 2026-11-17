import 'package:bull_ui/src/theme/bull_keypad_colors.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Every theme extension `bull_ui` components read, for a [ThemeData] of [brightness] whose palette is [colors].
///
/// Register the whole list in `ThemeData.extensions`, so a new extension reaches the app, the catalogue and the tests at once.
List<ThemeExtension<dynamic>> bullUiExtensions({
  required BullTheme colors,
  required Brightness brightness,
}) => [
  colors,
  BullShapes.standard,
  BullTypography.standard,
  BullKeypadColors.of(brightness),
];
