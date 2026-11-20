import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets('controlled denomination preserves exact sats across displays', (
    tester,
  ) async {
    final canonical = TextEditingController(text: '1');
    addTearDown(canonical.dispose);
    var unit = BitcoinUnit.sats;
    late StateSetter update;
    await tester.pumpWidget(
      wrapWithTheme(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BullAmountInput(
              canonicalUnit: BitcoinUnit.sats,
              amountController: canonical,
              bitcoinDisplayUnit: unit,
              onBitcoinUnitChanged: (next) => setState(() => unit = next),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('sats'));
    await tester.pumpAndSettle();
    expect(unit, BitcoinUnit.btc);
    expect(canonical.text, '1');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '0.00000001',
    );
    update(() => unit = BitcoinUnit.sats);
    await tester.pumpAndSettle();
    expect(canonical.text, '1');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '1',
    );
  });

  testWidgets('external denomination keeps an incomplete edit until valid', (
    tester,
  ) async {
    final canonical = TextEditingController(text: '1');
    addTearDown(canonical.dispose);
    var unit = BitcoinUnit.btc;
    late StateSetter update;
    await tester.pumpWidget(
      wrapWithTheme(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BullAmountInput(
              canonicalUnit: BitcoinUnit.sats,
              amountController: canonical,
              bitcoinDisplayUnit: unit,
            );
          },
        ),
      ),
    );
    expect(find.text('BTC'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '0.00000001',
    );
    await tester.enterText(find.byType(TextField), '0.');
    await tester.pumpAndSettle();
    update(() => unit = BitcoinUnit.sats);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '0.',
    );
    await tester.enterText(find.byType(TextField), '0.00000001');
    await tester.pumpAndSettle();
    expect(canonical.text, '1');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '1',
    );
    expect(find.text('sats'), findsOneWidget);
  });
}
