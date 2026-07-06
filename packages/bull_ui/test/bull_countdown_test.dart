import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullCountdown', () {
    testWidgets('renders the remaining m:ss and ticks down', (tester) async {
      final until = DateTime.now().toUtc().add(const Duration(seconds: 90));
      await tester.pumpWidget(
        wrapWithTheme(BullCountdown(until: until, onTimeout: () {})),
      );

      // ~90s left -> "1:" prefix.
      expect(find.textContaining('1:'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      // Still counting, no exception thrown.
      expect(find.byType(BullCountdown), findsOneWidget);
    });

    testWidgets('fires onTimeout immediately when already past', (
      tester,
    ) async {
      var fired = 0;
      final past = DateTime.now().toUtc().subtract(const Duration(seconds: 5));
      await tester.pumpWidget(
        wrapWithTheme(BullCountdown(until: past, onTimeout: () => fired++)),
      );

      expect(fired, 1);
      expect(find.text('0:00'), findsOneWidget);
    });
  });
}
