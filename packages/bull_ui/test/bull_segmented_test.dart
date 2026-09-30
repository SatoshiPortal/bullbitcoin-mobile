import 'package:bull_ui/bull_ui.dart';
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

    testWidgets('restyles the selected label when initialValue changes', (
      tester,
    ) async {
      Widget build(String initialValue) => wrapWithTheme(
        BullSegmented(
          items: const {'All', 'Frozen'},
          initialValue: initialValue,
          onSelected: (_) {},
        ),
      );
      Color? colorOf(String label) =>
          tester.widget<Text>(find.text(label)).style?.color;

      await tester.pumpWidget(build('All'));
      expect(colorOf('All'), testBullTheme.primary);

      await tester.pumpWidget(build('Frozen'));
      await tester.pumpAndSettle();

      expect(colorOf('Frozen'), testBullTheme.primary);
      expect(colorOf('All'), isNot(testBullTheme.primary));
    });
  });
}
