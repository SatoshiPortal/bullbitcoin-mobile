import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/cancel_limit_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../limit_order_fixtures.dart';
import '../../limit_test_orders.dart';

Future<LimitCancelAnswer> _cancel(
  LimitTestOrders orders, {
  ExchangeSession signedIn = limitSession,
}) => CancelLimitOrderUsecase(
  exchangeForTesting(
    limitOrders: orders,
    access: fixedAccessForTesting(ExchangeAccessSignedIn(signedIn)),
  ),
).execute(limitSession, 'lo-1');

void main() {
  test('a cancelled order is the answer', () async {
    final orders = LimitTestOrders()
      ..cancelled = Ok(limitOrder(status: LimitOrderStatus.cancelled));
    final answer = await _cancel(orders);
    expect(
      answer,
      isA<CancelAnsweredOrder>().having(
        (a) => a.order.status,
        'status',
        LimitOrderStatus.cancelled,
      ),
    );
    expect(orders.log, ['cancel lo-1']);
  });

  test('a refused cancel is left to the re-read', () async {
    final answer = await _cancel(
      LimitTestOrders()
        ..cancelled = const Err(
          ExchangeLimitOrderFailure(ExchangeLimitOrderProblem.cancel, 'filled'),
        ),
    );
    expect(answer, isA<CancelAnsweredUnsure>());
  });

  test('a rejected session is its own answer', () async {
    final answer = await _cancel(
      LimitTestOrders()
        ..cancelled = const Err(ExchangeSessionRejectedFailure()),
    );
    expect(answer, isA<CancelAnsweredSessionRejected>());
  });

  test('after a sign-in to another account the cancel is not sent', () async {
    final orders = LimitTestOrders()..current = limitOtherSession;
    final answer = await _cancel(orders, signedIn: limitOtherSession);
    expect(answer, isNot(isA<CancelAnsweredOrder>()));
    expect(orders.log, isEmpty);
  });
}
