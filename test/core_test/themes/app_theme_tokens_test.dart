import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapes, BullTypography, BullInputText;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

double? _radius(ShapeBorder? shape) {
  final radius = (shape as RoundedRectangleBorder?)?.borderRadius;
  return (radius as BorderRadius?)?.topLeft.x;
}

void main() {
  for (final type in AppThemeType.values) {
    testWidgets('every input inherits primary selection colours ($type)', (
      tester,
    ) async {
      final theme = AppTheme.themeData(type);
      final primary = theme.colorScheme.primary;
      expect(theme.textSelectionTheme.cursorColor, primary);
      expect(theme.textSelectionTheme.selectionHandleColor, primary);
      expect(
        theme.textSelectionTheme.selectionColor,
        primary.withValues(alpha: 0.3),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                const TextField(),
                BullInputText(onChanged: (_) {}, value: 'Payment'),
              ],
            ),
          ),
        ),
      );
      for (var index = 0; index < 2; index++) {
        final field = find.byType(TextField).at(index);
        await tester.tap(field);
        await tester.pump();
        final input = tester.widget<EditableText>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        expect(input.cursorColor, primary);
        expect(input.selectionColor, primary.withValues(alpha: 0.3));
      }
      expect(find.byType(EditableText), findsNWidgets(2));
    });
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
