import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_ui/bull_ui.dart' show BullShimmerLine;
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

void main() {
  testWidgets('does not accept an amount while the currency is unknown', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ExchangeAmountInputField(amountController: controller),
        ),
      ),
    );

    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(BullShimmerLine), findsOneWidget);
  });

  testWidgets('switching a named currency control clears the input', (
    tester,
  ) async {
    final controller = TextEditingController(text: '12.34');
    addTearDown(controller.dispose);
    var fiat = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ExchangeAmountInputField(
              amountController: controller,
              bitcoinUnit: BitcoinUnit.sats,
              fiatCurrency: FiatCurrency.cad,
              isFiatCurrencyInput: fiat,
              onIsFiatCurrencyInputChanged: (value) =>
                  setState(() => fiat = value),
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(ExchangeAmountInputField));
    final label = ExchangeLocalizations.of(context)
        .exchangeCurrencyDropdownTitle;
    await tester.tap(find.byTooltip(label));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(fiat, isFalse);
  });
}
