import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullTopBar', () {
    testWidgets('paints the given background colour', (tester) async {
      const background = Color(0xFF123456);
      await tester.pumpWidget(
        wrapWithTheme(const BullTopBar(title: 'Import', color: background)),
      );

      expect(find.text('Import'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Container && w.color == background),
        findsOneWidget,
      );
    });

    testWidgets('shows a title widget in place of the title text', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullTopBar(title: 'Import', titleWidget: Text('Logo')),
        ),
      );

      expect(find.text('Logo'), findsOneWidget);
      expect(find.text('Import'), findsNothing);
    });
  });
}
