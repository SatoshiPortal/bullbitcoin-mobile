import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart' show Scaffold;
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullReferenceNotice', () {
    testWidgets('shows the message, the reference and fires the action', (
      tester,
    ) async {
      var left = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(
            body: BullReferenceNotice(
              message: 'Payment sent; keep the ID below.',
              reference: 'abc123',
              copiedMessage: 'Copied',
              actionLabel: 'Leave',
              onAction: () => left++,
            ),
          ),
        ),
      );

      expect(find.text('Payment sent; keep the ID below.'), findsOneWidget);
      expect(find.text('abc123'), findsOneWidget);
      expect(find.byType(BullCopyField), findsOneWidget);

      await tester.tap(find.text('Leave'));
      expect(left, 1);
    });

    testWidgets('preserves explicit primary action colours', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(
            body: BullReferenceNotice(
              message: 'Keep the reference',
              reference: 'public-reference',
              copiedMessage: 'Copied',
              actionLabel: 'Continue',
              actionBgColor: testBullTheme.primary,
              actionTextColor: testBullTheme.onPrimary,
              onAction: () => taps++,
            ),
          ),
        ),
      );
      final scope = find.byType(BullButton);
      final fill =
          tester
                  .widget<Container>(
                    find
                        .descendant(of: scope, matching: find.byType(Container))
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      final text = tester.widget<BullText>(
        find.descendant(of: scope, matching: find.byType(BullText)),
      );
      expect(fill.color, testBullTheme.primary);
      expect(text.color, testBullTheme.onPrimary);
      await tester.tap(find.text('Continue'));
      expect(taps, 1);
    });

    testWidgets('defaults to the tertiary card and secondary action', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(
            body: BullReferenceNotice(
              message: 'm',
              reference: 'r',
              copiedMessage: 'c',
              actionLabel: 'a',
              onAction: () {},
            ),
          ),
        ),
      );

      final card = tester.widget<BullInfoCard>(find.byType(BullInfoCard));
      expect(card.tagColor, testBullTheme.tertiary);
      expect(card.bgColor, testBullTheme.tertiaryContainer);
      final scope = find.byType(BullButton);
      final fill =
          tester
                  .widget<Container>(
                    find
                        .descendant(of: scope, matching: find.byType(Container))
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      final text = tester.widget<BullText>(
        find.descendant(of: scope, matching: find.byType(BullText)),
      );
      expect(fill.color, testBullTheme.secondary);
      expect(text.color, testBullTheme.onSecondary);
    });
  });
}
