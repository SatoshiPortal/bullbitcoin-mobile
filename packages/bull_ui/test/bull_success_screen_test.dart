import 'package:bull_ui/bull_ui.dart';
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
}
