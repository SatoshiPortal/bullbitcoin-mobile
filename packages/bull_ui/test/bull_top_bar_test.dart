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

    testWidgets('names its back and close buttons', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullTopBar(title: 'Import', onBack: () {}, onAction: () {}),
        ),
      );

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
    });

    testWidgets('names a custom trailing action with its tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullTopBar(
            title: 'Coins',
            onAction: () {},
            actionIcon: BullIcons.tune,
            actionTooltip: 'Sort & Filter',
          ),
        ),
      );

      expect(find.byTooltip('Sort & Filter'), findsOneWidget);
    });

    testWidgets('keeps a long title on one ellipsized header line', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const title = 'A very long localized screen title that cannot fit';
      await tester.pumpWidget(
        wrapWithTheme(BullTopBar(title: title, onBack: () {})),
      );

      final text = tester.widget<Text>(find.text(title));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSemantics(find.text(title)),
        matchesSemantics(label: title, isHeader: true),
      );
      semantics.dispose();
    });
  });
}
