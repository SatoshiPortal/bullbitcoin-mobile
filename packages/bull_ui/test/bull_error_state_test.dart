import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullErrorState', () {
    testWidgets('shows the message and retries on tap', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullErrorState(
            message: 'Could not load',
            retryLabel: 'Retry',
            onRetry: () => retries++,
          ),
        ),
      );

      expect(find.text('Could not load'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retries, 1);
    });

    testWidgets('disables the button without a retry callback', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullErrorState(
            message: 'Could not load',
            retryLabel: 'Retry',
            onRetry: null,
          ),
        ),
      );

      final button = tester.widget<BullButton>(find.byType(BullButton));
      expect(button.disabled, isTrue);
    });
  });
}
