import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders caller content and invokes close', (tester) async {
    var closeCalls = 0;

    await tester.pumpWidget(
      wrapWithTheme(
        BullSuccessScreen(
          title: 'Sell',
          headline: 'Order completed',
          amountLine: '100 sats',
          message: const Text('Payment delivered'),
          onClose: () => closeCalls++,
          actions: const [Text('View details')],
        ),
      ),
    );

    expect(find.text('Sell'), findsOneWidget);
    expect(find.text('Order completed'), findsOneWidget);
    expect(find.text('100 sats'), findsOneWidget);
    expect(find.text('Payment delivered'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);

    await tester.tap(find.byIcon(BullIcons.close));
    expect(closeCalls, 1);
  });

  testWidgets('uses the caller-provided icon', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullSuccessScreen(
          title: 'Pay',
          headline: 'Complete',
          icon: const Text('custom icon'),
          onClose: () {},
        ),
      ),
    );

    expect(find.text('custom icon'), findsOneWidget);
    expect(find.byIcon(BullIcons.checkCircle), findsNothing);
  });

  testWidgets('applies the caller overrides', (tester) async {
    const background = Color(0xFF000000);

    await tester.pumpWidget(
      wrapWithTheme(
        BullSuccessScreen(
          title: 'Test',
          headline: 'Done',
          onClose: () {},
          showCloseButton: false,
          backgroundColor: background,
          headlineStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    expect(find.byIcon(BullIcons.close), findsNothing);
    expect(
      tester
          .widget<Scaffold>(
            find.descendant(
              of: find.byType(BullScaffold),
              matching: find.byType(Scaffold),
            ),
          )
          .backgroundColor,
      background,
    );
    final headline = tester.widget<Text>(find.text('Done')).style;
    expect(headline?.fontSize, 16);
    expect(headline?.fontWeight, FontWeight.w700);
  });
}
