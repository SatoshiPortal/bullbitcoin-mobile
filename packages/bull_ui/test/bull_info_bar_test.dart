import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  // Regression: the 4px left accent must not be a non-uniform Border combined
  // with a borderRadius — Flutter asserts on that pairing at build time.
  for (final tone in BullInfoTone.values) {
    testWidgets('BullInfoBar renders without asserting ($tone)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(BullInfoBar(message: 'Heads up', tone: tone)),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Heads up'), findsOneWidget);
    });
  }
}
