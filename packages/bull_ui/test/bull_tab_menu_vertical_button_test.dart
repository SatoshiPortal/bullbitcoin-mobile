import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart' show InkWell;
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullTabMenuVerticalButton', () {
    Color? backgroundOf(WidgetTester tester) {
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(InkWell),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration! as BoxDecoration).color;
    }

    testWidgets('renders the title and fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullTabMenuVerticalButton(title: 'Import', onTap: () => taps++),
        ),
      );

      await tester.tap(find.text('Import'));

      expect(taps, 1);
      expect(backgroundOf(tester), testBullTheme.surface);
    });

    testWidgets('greys out the row when onTap is null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullTabMenuVerticalButton(title: 'Import', onTap: null),
        ),
      );

      expect(backgroundOf(tester), testBullTheme.border);
    });

    testWidgets('shows the leading icon when given', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullTabMenuVerticalButton(
            title: 'Import',
            icon: const Text('icon'),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('icon'), findsOneWidget);
    });
  });
}
