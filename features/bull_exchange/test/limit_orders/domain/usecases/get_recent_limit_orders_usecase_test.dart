import 'package:bull_exchange/src/limit_orders/domain/usecases/get_recent_limit_orders_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../limit_order_fixtures.dart';
import '../../limit_test_orders.dart';

void main() {
  test('settles the journal, then reads the recent orders', () async {
    final orders = LimitTestOrders()..recent = Ok([limitOrder(id: 'lo-7')]);
    final points = <String>[];
    final read = await GetRecentLimitOrdersUsecase(
      exchangeForTesting(
        limitOrders: orders,
        unknownWrites: InMemoryUnknownWriteJournal(),
        readSessionPoint: () async {
          points.add('point');
          return const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1));
        },
      ),
    ).execute();
    expect((read as ReadGot<List<LimitOrder>>).value.single.id, 'lo-7');
    expect(points, ['point']);
    expect(orders.log, ['recent']);
  });

  test('a failed read is never a list', () async {
    final read = await GetRecentLimitOrdersUsecase(
      exchangeForTesting(
        limitOrders: LimitTestOrders()
          ..recent = const Err(ExchangeSessionRejectedFailure()),
      ),
    ).execute();
    expect(read, isA<ReadSessionRejected<List<LimitOrder>>>());
  });
}
