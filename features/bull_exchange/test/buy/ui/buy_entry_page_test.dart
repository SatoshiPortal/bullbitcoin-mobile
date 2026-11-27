import 'dart:ui' show Tristate;

import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/buy/domain/buy_event.dart';
import 'package:bull_exchange/src/buy/domain/buy_state.dart';
import 'package:bull_exchange/src/buy/ui/screens/buy_entry_page.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Ok;

import '../buy_fixtures.dart';

/// The fixture's default payout wallet is Liquid, which offers no payjoin; the
/// payjoin row shows once the bitcoin wallet is the destination.
final _payjoinEntry =
    applyBuy(buyLoadingState, [
          BuyContextLoaded(1, Ok(buyContext)),
          const BuyAmountChanged(
            AmountRateArrived(ExchangeCatalog.cad, Ok(50000.0)),
          ),
          BuyDestinationPicked(buyBitcoinWallet.option),
          BuyDestinationChanged(
            PickResolved(
              buyBitcoinWallet.option,
              const Ok(buyBitcoinDestination),
            ),
          ),
        ]).state
        as BuyEntry;

Widget _payoutField({
  required BtcNetwork type,
  required String value,
  required String label,
  required String hint,
  required bool enabled,
  required ValueChanged<String> onChanged,
  required ValueChanged<String?> onValidated,
}) => const SizedBox.shrink();

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: BuyEntryPage(
        entry: _payjoinEntry,
        unit: BitcoinUnit.sats,
        payoutField: _payoutField,
        onEvent: (_) {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the payjoin switch names itself and carries its state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    final labels = ExchangeLocalizations.of(
      tester.element(find.byType(BuyEntryPage)),
    );
    final node = tester.getSemantics(find.byType(BullSwitch));
    expect(node.label, labels.payjoinUseToggle);
    expect(node.flagsCollection.isToggled, Tristate.isTrue);

    handle.dispose();
  });
}
