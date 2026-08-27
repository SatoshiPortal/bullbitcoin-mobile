import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullCheckbox', () {
    testWidgets('toggles and reports the new value on tap', (tester) async {
      var checked = false;
      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return BullCheckbox(
                checked: checked,
                onChanged: (v) => setState(() => checked = v),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(BullCheckbox));
      await tester.pump();
      expect(checked, isTrue);

      await tester.tap(find.byType(BullCheckbox));
      await tester.pump();
      expect(checked, isFalse);
    });

    testWidgets('is inert when onChanged is null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const BullCheckbox(checked: false, onChanged: null)),
      );

      // No callback to fire; tapping must not throw.
      await tester.tap(find.byType(BullCheckbox));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('exposes a 44px accessible tap target', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(BullCheckbox(checked: true, onChanged: (_) {})),
      );

      final size = tester.getSize(
        find.descendant(
          of: find.byType(BullCheckbox),
          matching: find.byType(SizedBox).first,
        ),
      );
      expect(size.width, 44);
      expect(size.height, 44);
    });
  });
}
