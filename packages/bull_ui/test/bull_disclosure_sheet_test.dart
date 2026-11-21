import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders headings, callouts, and bullet lists', (tester) async {
    const body = '''
Introductory paragraph.

> Recommendation
> Keep only a small balance here.

## What is the Instant Payments Wallet?

Section paragraph.

### Example

- **Maximum balance:** 0.01 BTC
- Plain bullet
''';

    await tester.pumpWidget(
      wrapWithTheme(
        const BullDisclosureSheet(
          title: 'Disclosure',
          body: body,
          closeLabel: 'Close',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Introductory paragraph.'), findsOneWidget);
    expect(find.text('Recommendation'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    final sectionHeading = tester.widget<Text>(
      find.text('What is the Instant Payments Wallet?'),
    );
    expect(sectionHeading.style?.fontWeight, FontWeight.w600);

    final exampleHeading = tester.widget<Text>(find.text('Example'));
    expect(exampleHeading.style?.fontWeight, FontWeight.w600);

    expect(
      find.text('Maximum balance: 0.01 BTC', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Plain bullet'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('disclosure link and close action are named 48 dp targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const BullDisclosureLink(
          label: 'Learn more',
          semanticLabel: 'Learn more about Liquid',
          title: 'Liquid disclosure',
          body: 'Disclosure details.',
          closeLabel: 'Close disclosure',
        ),
      ),
    );

    final link = find.byType(InkWell);
    expect(tester.getSize(link).shortestSide, greaterThanOrEqualTo(48));
    expect(
      find.bySemanticsLabel(RegExp('Learn more about Liquid')),
      findsWidgets,
    );

    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Disclosure details.'), findsOneWidget);
    final close = find.byTooltip('Close disclosure');
    expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(48));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(BullDisclosureSheet), findsNothing);
  });
}
