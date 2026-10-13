import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullSegmented', () {
    testWidgets('reports the tapped segment via onSelected', (tester) async {
      String? selected;
      await tester.pumpWidget(
        wrapWithTheme(
          BullSegmented(
            items: const {'All', 'Frozen'},
            onSelected: (v) => selected = v,
          ),
        ),
      );

      await tester.tap(find.text('Frozen'));
      await tester.pumpAndSettle();

      expect(selected, 'Frozen');
    });

    testWidgets('does not select a disabled segment', (tester) async {
      String? selected;
      await tester.pumpWidget(
        wrapWithTheme(
          BullSegmented(
            items: const {'All', 'Frozen'},
            disabledItems: const {'Frozen'},
            onSelected: (v) => selected = v,
          ),
        ),
      );

      await tester.tap(find.text('Frozen'));
      await tester.pumpAndSettle();

      expect(selected, isNull);
    });

    // Regression: the copy rounded every corner to BullRadius.xs, doubling the
    // radius of the original and making the control visibly rounder than the
    // rest of the design system.
    testWidgets('clips to the design-system corner radius', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullSegmented(items: const {'All', 'Frozen'}, onSelected: (_) {}),
        ),
      );

      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
      expect(clip.borderRadius, BorderRadius.circular(BullRadius.xxs));
    });

    // Regression: the copy greyed disabled labels with textMuted instead of
    // outline, rendering them darker than the original in light mode.
    testWidgets('greys a disabled label with the outline token', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullSegmented(
            items: const {'All', 'Frozen'},
            disabledItems: const {'Frozen'},
            onSelected: (_) {},
          ),
        ),
      );

      final label = tester.widget<Text>(find.text('Frozen'));
      expect(label.style?.color, testBullTheme.outline.withValues(alpha: 0.5));
    });
  });
}
