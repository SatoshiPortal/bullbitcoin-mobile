import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullShapes, BullTypography;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

double? _radius(ShapeBorder? shape) {
  final radius = (shape as RoundedRectangleBorder?)?.borderRadius;
  return (radius as BorderRadius?)?.topLeft.x;
}

void main() {
  for (final type in AppThemeType.values) {
    test(
      'Bull widgets and Material themes share one set of tokens ($type)',
      () {
        final theme = AppTheme.themeData(type);
        expect(theme.extension<BullShapes>(), same(AppTheme.shapes));
        expect(
          theme.extension<BullTypography>()?.toTextTheme(),
          theme.textTheme,
        );
        expect(_radius(theme.cardTheme.shape), AppTheme.shapes.card);
        expect(_radius(theme.listTileTheme.shape), AppTheme.shapes.card);
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          AppTheme.typography.body.fontFamily,
        );
      },
    );
  }
}
