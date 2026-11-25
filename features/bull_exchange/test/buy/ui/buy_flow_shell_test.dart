import 'package:bull_exchange/src/buy/presentation/buy_flow.dart';
import 'package:bull_exchange/src/buy/ui/buy_flow_shell.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

import '../buy_fixtures.dart';

Widget _field({
  required BtcNetwork type,
  required String value,
  required String label,
  required String hint,
  required bool enabled,
  required ValueChanged<String> onChanged,
  required ValueChanged<String?> onValidated,
}) => const SizedBox.shrink();

final BuyFlowUi _ui = (
  payoutField: _field,
  bitcoinAsset: '',
  openOrder: (_, _) {},
);

List<String> _keys(BuyFlowState state) => [
  for (final page in buyPagesFor(
    state,
    ui: _ui,
    unit: BitcoinUnit.sats,
    onEvent: (_) {},
    now: () => buyBeforeDeadline,
  ))
    (page.key! as ValueKey<String>).value,
];

void main() {
  test('each state is its own page stack, with the entry under an order', () {
    expect(_keys(buyLoadingState), ['buy-entry']);
    expect(_keys(buyEntryState), ['buy-entry']);
    expect(_keys(buyOrderingState), ['buy-entry', 'buy-order']);
    expect(_keys(buyReviewState), ['buy-entry', 'buy-order']);
    expect(_keys(buyConfirmingState), ['buy-entry', 'buy-confirm']);
    expect(_keys(buyDoneState), ['buy-end']);
    expect(_keys(const BuySessionEnded()), ['buy-end']);
  });

  test('a detour is a page over the entry, which keeps the draft', () {
    final detour = applyBuy(buyEntryState, const [
      BuyAmountChanged(AmountTyped('500')),
      BuyContinuePressed(),
    ]).state;
    expect((detour as BuyEntry).amount, isA<AmountFundingDetour>());
    expect(_keys(detour), ['buy-entry', 'buy-detour']);
  });

  test('a confirmed order has no entry under it: Back cannot reorder', () {
    final done = applyBuy(buyConfirmingState, [
      BuyConfirmChanged(
        ConfirmAnswered(1, buyDone(buyOrder(status: OrderStatus.inProgress))),
      ),
    ]).state;
    expect(_keys(done), isNot(contains('buy-entry')));
  });
}
