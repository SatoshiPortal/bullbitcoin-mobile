import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullDialPad', () {
    testWidgets('reports digit, decimal and backspace taps', (tester) async {
      final pressed = <String>[];
      var backspaces = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullDialPad(
            onNumberPressed: pressed.add,
            onBackspacePressed: () => backspaces++,
          ),
        ),
      );

      await tester.tap(find.text('7'));
      await tester.tap(find.text('.'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(pressed, ['7', '.']);
      expect(backspaces, 1);
    });

    testWidgets('hides the decimal key when onlyDigits is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullDialPad(
            onlyDigits: true,
            onNumberPressed: (_) {},
            onBackspacePressed: () {},
          ),
        ),
      );

      expect(find.text('.'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });
  });
}
