import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final type in AppThemeType.values) {
    final colors = type == AppThemeType.light
        ? AppColors.light
        : AppColors.dark;
    for (final width in [390.0, 900.0]) {
      testWidgets('raw Material sheet follows global defaults: $type/$width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(type),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const SizedBox(
                      height: 120,
                      child: Text('Public content'),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(
          material.color,
          type == AppThemeType.light ? colors.background : colors.surface,
        );
        expect(
          (material.shape as RoundedRectangleBorder?)?.side,
          BorderSide.none,
        );
        expect(
          (material.shape as RoundedRectangleBorder?)?.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(8)),
        );
        final bounds = tester.getRect(find.byType(BottomSheet));
        expect(bounds.left, 0);
        expect(bounds.right, width);
        final barrier = tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .where((widget) => widget.color != null)
            .last;
        expect(
          barrier.color,
          colors.scrim.withValues(
            alpha: type == AppThemeType.light ? 0.45 : 0.60,
          ),
        );
      });
    }
    testWidgets(
      'raw fields resolve semantic borders and preserve explicit borderless fields: $type',
      (tester) async {
        final theme = AppTheme.themeData(type);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(body: TextField()),
          ),
        );
        final decoration = tester
            .widget<InputDecorator>(find.byType(InputDecorator))
            .decoration;
        expect(decoration.fillColor, colors.surface);
        expect(decoration.filled, isTrue);
        for (final states in [
          <WidgetState>{},
          {WidgetState.focused},
          {WidgetState.disabled},
        ]) {
          expect(
            WidgetStateProperty.resolveAs(
              decoration.border,
              states,
            )?.borderSide.color,
            colors.border,
          );
        }
        expect(
          WidgetStateProperty.resolveAs(decoration.border, {
            WidgetState.error,
          })?.borderSide.color,
          colors.error,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: TextField(
                decoration: InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
        );
        expect(
          tester
              .widget<InputDecorator>(find.byType(InputDecorator))
              .decoration
              .border,
          InputBorder.none,
        );
      },
    );
  }
}
