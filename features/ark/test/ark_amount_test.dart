import 'package:bull_ark/src/ui/ark_amount.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Builder;
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;

void main() {
  final price = BitcoinPrice(
    currency: SupportedCurrency.cad,
    fiatAmount: 100000,
    fetchedAt: DateTime.utc(2026, 11, 17),
  );

  testWidgets('satoshi grouping preserves integers beyond double precision', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => BullText(
            formatArkSats(context, Sats(BigInt.parse('9007199254740993'))),
          ),
        ),
      ),
    );
    expect(find.text('9,007,199,254,740,993 sats'), findsOneWidget);
  });

  for (final hide in [false, true]) {
    for (final ready in [false, true]) {
      testWidgets('fiat follows actual currency, ready=$ready hidden=$hide', (
        tester,
      ) async {
        Widget equivalent(BitcoinPrice? observation) => BullAmountScope(
          snapshot: BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: hide,
            isReady: ready,
          ),
          writeUnit: (_) async => true,
          child: ArkFiatAmount(amount: Sats.fromInt(1234), price: observation),
        );
        await tester.pumpWidget(app(equivalent(price)));
        expect(
          find.text('1.23 CAD'),
          ready && !hide ? findsOneWidget : findsNothing,
        );
        await tester.pumpWidget(app(equivalent(null)));
        expect(find.text('1.23 CAD'), findsNothing);
        expect(find.text('0.00 CAD'), findsNothing);
      });
    }
  }

  testWidgets('absent amount preferences hide fiat instead of exposing it', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ArkFiatAmount(amount: Sats.fromInt(1234), price: price),
        amountPreferences: null,
      ),
    );
    expect(find.text('1.23 CAD'), findsNothing);
  });
}
