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

    // Regression: `enabled` was missing from the duplicated widget. The unlock
    // screen drives it from `timeoutSeconds == 0 && !isVerifying`, so without
    // it a user could keep entering PINs during a failed-attempt lockout.
    testWidgets('ignores every tap while disabled', (tester) async {
      final pressed = <String>[];
      var backspaces = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullDialPad(
            enabled: false,
            onNumberPressed: pressed.add,
            onBackspacePressed: () => backspaces++,
          ),
        ),
      );

      await tester.tap(find.text('7'));
      await tester.tap(find.text('0'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(pressed, isEmpty);
      expect(backspaces, 0);
    });

    testWidgets('dims the keys while disabled', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullDialPad(
            enabled: false,
            onNumberPressed: (_) {},
            onBackspacePressed: () {},
          ),
        ),
      );

      final digit = tester.widget<BullText>(
        find
            .ancestor(of: find.text('7'), matching: find.byType(BullText))
            .first,
      );
      expect(digit.color, testBullTheme.textMuted);

      final icon = tester.widget<Icon>(find.byIcon(Icons.backspace_outlined));
      expect(icon.color, testBullTheme.textMuted);
    });

    testWidgets('keeps the keys legible while enabled', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullDialPad(onNumberPressed: (_) {}, onBackspacePressed: () {}),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.backspace_outlined));
      expect(icon.color, testBullTheme.onSurface);
    });
  });
}
