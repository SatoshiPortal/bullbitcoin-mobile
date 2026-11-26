import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/buy/domain/usecases/confirm_buy_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../buy_fixtures.dart';
import '../../buy_test_ports.dart';

ConfirmSend<BuyConfirmTarget> _send() {
  final next = transitionBuyFlow(
    buyReviewState,
    BuyConfirmPressed(buyBeforeDeadline),
  );
  return next.effects.whereType<BuyConfirmEffect>().single.effect
      as ConfirmSend<BuyConfirmTarget>;
}

void main() {
  test('confirms the quoted order; the done order keeps its URI', () async {
    final orders = BuyTestOrders()
      ..confirmed = WriteDone(buyOrder(status: OrderStatus.inProgress));
    final uris = BuyPayjoinUris()..attachToOrder('b-1', 'bitcoin:x?pj=y');
    final send = _send();
    final answer = await ConfirmBuyOrderUsecase(
      exchangeForTesting(orders: (_) => orders),
      uris,
    ).execute(buySession, send);
    expect(answer.attempt, send.attempt);
    final result =
        (answer.answer as GateAdmitted<ExchangeWrite<BuyOrder>>).result;
    expect((result as WriteDone<BuyOrder>).value.bip21URI, 'bitcoin:x?pj=y');
    expect(orders.log, ['confirm b-1']);
  });

  test('an unknown outcome is the answer, not a confirmed order', () async {
    final orders = BuyTestOrders()
      ..confirmed = const WriteOutcomeUnknown('lost');
    final answer = await ConfirmBuyOrderUsecase(
      exchangeForTesting(
        orders: (_) => orders,
        unknownWrites: InMemoryUnknownWriteJournal(),
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
      ),
      BuyPayjoinUris(),
    ).execute(buySession, _send());
    expect(
      (answer.answer as GateAdmitted<ExchangeWrite<BuyOrder>>).result,
      isA<WriteOutcomeUnknown<BuyOrder>>(),
    );
  });
}
