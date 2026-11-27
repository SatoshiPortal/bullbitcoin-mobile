import 'package:bull_exchange/src/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../limit_order_fixtures.dart';
import '../../limit_test_orders.dart';

Exchange _exchange(LimitTestOrders orders, ExchangeSession signedIn) =>
    exchangeForTesting(
      limitOrders: orders,
      access: fixedAccessForTesting(ExchangeAccessSignedIn(signedIn)),
      unknownWrites: InMemoryUnknownWriteJournal(),
      readSessionPoint: () async =>
          const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
    );

void main() {
  test('a done create answers the order the exchange made', () async {
    final orders = LimitTestOrders()..created = Ok(limitOrder());
    final send = limitCreateSend();
    final answer = await CreateLimitOrderUsecase(
      _exchange(orders, limitSession),
    ).execute(limitSession, send);
    expect(answer.attempt, send.attempt);
    final result = answer.answer;
    expect((result as Ok<LimitOrder, ExchangeWriteFailure>).value.id, 'lo-1');
    expect(orders.log, ['create 200.0 CAD 80000.0 bc1qdefault']);
  });

  test('after a sign-in to another account the create is not sent', () async {
    final orders = LimitTestOrders()..current = limitOtherSession;
    final answer = await CreateLimitOrderUsecase(
      _exchange(orders, limitOtherSession),
    ).execute(limitSession, limitCreateSend());
    expect(answer.answer, isNot(isA<Ok<LimitOrder, ExchangeWriteFailure>>()));
    expect(orders.log, isEmpty);
  });

  test('an unknown outcome is kept, never read as created', () async {
    final orders = LimitTestOrders()
      ..created = const Err(ExchangeWriteOutcomeUnknownFailure('lost'));
    final answer = await CreateLimitOrderUsecase(
      _exchange(orders, limitSession),
    ).execute(limitSession, limitCreateSend());
    expect(
      answer.answer,
      isA<Err<LimitOrder, ExchangeWriteFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeWriteOutcomeUnknownFailure>(),
      ),
    );
  });
}
