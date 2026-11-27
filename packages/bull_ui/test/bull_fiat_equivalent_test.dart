import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'test_app.dart';

Future<void> _pump(
  WidgetTester tester,
  String? formatted, {
  bool hide = false,
  bool ready = true,
}) => tester.pumpWidget(
  wrapWithTheme(
    BullAmountScope(
      snapshot: BullAmountSnapshot(
        unit: BitcoinUnit.sats,
        hideAmounts: hide,
        isReady: ready,
      ),
      writeUnit: (_) async => true,
      child: BullFiatEquivalent(formatted),
    ),
  ),
);

void main() {
  testWidgets('shows the fiat value as an approximation', (tester) async {
    await _pump(tester, '12.34 CAD');
    expect(find.text('~12.34 CAD'), findsOneWidget);
  });

  testWidgets('hides the value but keeps the currency', (tester) async {
    await _pump(tester, '12.34 CAD', hide: true);
    expect(find.textContaining('12.34'), findsNothing);
    expect(find.textContaining('CAD'), findsOneWidget);
  });

  testWidgets('hides the value until amounts are ready', (tester) async {
    await _pump(tester, '12.34 CAD', ready: false);
    expect(find.textContaining('12.34'), findsNothing);
  });

  testWidgets('shows nothing without a price', (tester) async {
    await _pump(tester, null);
    expect(find.byType(Text), findsNothing);
    await _pump(tester, '');
    expect(find.byType(Text), findsNothing);
  });
}
