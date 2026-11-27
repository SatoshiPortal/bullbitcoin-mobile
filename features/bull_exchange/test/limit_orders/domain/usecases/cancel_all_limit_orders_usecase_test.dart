import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/cancel_all_limit_orders_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../limit_order_fixtures.dart';
import '../../limit_test_orders.dart';

Future<LimitCancelAllAnswer> _cancelAll(
  LimitTestOrders orders, {
  ExchangeSession? session = limitSession,
  ExchangeSession signedIn = limitSession,
}) => CancelAllLimitOrdersUsecase(
  exchangeForTesting(
    limitOrders: orders,
    access: fixedAccessForTesting(ExchangeAccessSignedIn(signedIn)),
  ),
).execute(session);

void main() {
  test('a done cancel-all is the answer', () async {
    final orders = LimitTestOrders()..cancelledAll = const Ok([]);
    expect(await _cancelAll(orders), isA<CancelAllDone>());
    expect(orders.log, ['cancelAll']);
  });

  test('a refused cancel-all is left to the list read', () async {
    expect(
      await _cancelAll(
        LimitTestOrders()..cancelledAll = const Err(ExchangeNetworkFailure()),
      ),
      isA<CancelAllUnsure>(),
    );
  });

  test('a rejected session is its own answer', () async {
    expect(
      await _cancelAll(
        LimitTestOrders()
          ..cancelledAll = const Err(
            ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
          ),
      ),
      isA<CancelAllSessionRejected>(),
    );
  });

  test('without a session, or after a sign-in to another account, nothing '
      'is sent', () async {
    final orders = LimitTestOrders()..current = limitOtherSession;
    expect(
      await _cancelAll(orders, session: null),
      isA<CancelAllSessionRejected>(),
    );
    expect(
      await _cancelAll(orders, signedIn: limitOtherSession),
      isNot(isA<CancelAllDone>()),
    );
    expect(orders.log, isEmpty);
  });
}
