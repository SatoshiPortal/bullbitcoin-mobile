import 'package:bull_exchange/src/limit_orders/domain/usecases/get_recent_limit_orders_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../limit_order_fixtures.dart';
import '../../limit_test_orders.dart';

void main() {
  test(
    "reconciles the session's journal, then reads the recent orders",
    () async {
      final orders = LimitTestOrders()..recent = Ok([limitOrder(id: 'lo-7')]);
      final journal = InMemoryUnknownWriteJournal();
      final _ = await journal.record(
        UnknownWriteDraft(
          kind: UnknownWriteKind.limitOrderCreate,
          environment: limitSession.environment,
          request: const {
            'limitPrice': '90000.00',
            'fiatAmount': '100.00',
            'currency': 'CAD',
            'address': 'bc1qlimit',
          },
        ),
      );
      final read = await GetRecentLimitOrdersUsecase(
        exchangeForTesting(
          access: fixedAccessForTesting(
            const ExchangeAccessSignedIn(limitSession),
          ),
          limitOrders: orders,
          unknownWrites: journal,
          readSessionPoint: () async =>
              const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
        ),
      ).execute(limitSession);
      expect(
        (read as Ok<List<LimitOrder>, ExchangeReadFailure>).value.single.id,
        'lo-7',
      );
      // The reconcile's re-read of the recent orders, then the list read.
      expect(orders.log, ['recent', 'recent']);
      expect(orders.sessions, [limitSession, limitSession]);
    },
  );

  test('a failed read is never a list', () async {
    final read = await GetRecentLimitOrdersUsecase(
      exchangeForTesting(
        limitOrders: LimitTestOrders()
          ..recent = const Err(
            ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
          ),
      ),
    ).execute(limitSession);
    expect(
      read,
      isA<Err<List<LimitOrder>, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeSessionRejectedFailure>(),
      ),
    );
  });
}
