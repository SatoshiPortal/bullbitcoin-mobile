import 'package:bull_exchange/src/buy/domain/buy_accelerate_state.dart';
import 'package:bull_exchange/src/buy/domain/buy_accelerate_event.dart';
import 'package:bull_exchange/src/buy/domain/buy_accelerate_effect.dart';
import 'package:bull_exchange/src/buy/domain/usecases/accelerate_buy_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../buy_fixtures.dart';
import '../../buy_test_ports.dart';

/// The accelerate the flow sends for b-1 once its quote loaded.
ConfirmSend<AccelerateTarget> _send() {
  var next = accelerateFlowStart(buySession, 'b-1');
  next = next.state.next(
    AccelerateLoaded(
      1,
      Ok(
        AccelerateQuote(
          buyOrder(status: OrderStatus.inProgress),
          const AccelerateFee(satPerVbyte: 2.5, sats: 350, fiatPerBitcoin: 1),
          const [],
        ),
      ),
    ),
  );
  next = next.state.next(const AccelerateConfirmPressed());
  return next.effects.whereType<AccelerateConfirmEffect>().single.effect
      as ConfirmSend<AccelerateTarget>;
}

void main() {
  test('accelerates the order through the gate on the session '
      'environment', () async {
    final environments = <ExchangeEnvironment>[];
    final orders = BuyTestOrders()
      ..accelerated = Ok(buyOrder(status: OrderStatus.inProgress));
    final send = _send();
    final answer = await AccelerateBuyOrderUsecase(
      exchangeForTesting(
        orders: (environment) {
          environments.add(environment);
          return orders;
        },
      ),
    ).execute(buySession, send);
    expect(answer.attempt, send.attempt);
    expect(answer.answer, isA<Ok<BuyOrder, ExchangeWriteFailure>>());
    expect(orders.log, ['accelerate b-1']);
    expect(environments, [ExchangeEnvironment.mainnet]);
  });

  test('an unknown outcome is journaled, never read as done', () async {
    final journal = InMemoryUnknownWriteJournal();
    final orders = BuyTestOrders()
      ..accelerated = const Err(ExchangeWriteOutcomeUnknownFailure('lost'));
    final answer = await AccelerateBuyOrderUsecase(
      exchangeForTesting(
        orders: (_) => orders,
        unknownWrites: journal,
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
      ),
    ).execute(buySession, _send());
    expect(
      answer.answer,
      isA<Err<BuyOrder, ExchangeWriteFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeWriteOutcomeUnknownFailure>(),
      ),
    );
    expect(journal.entries, hasLength(1));
  });
}
