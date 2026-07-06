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
  });
}
