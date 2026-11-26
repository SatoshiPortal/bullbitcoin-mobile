import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../withdraw/withdraw_fixtures.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 4,
  sessionId: 's',
);

final class _Orders extends Fake implements OrdersRepository {
  final Result<List<Order>, ExchangeFailure> list;
  final asked = <String>[];

  _Orders({this.list = const Ok([])});

  @override
  Future<Result<List<Order>, ExchangeFailure>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    asked.add('list ${type?.name}');
    return list;
  }
}

Exchange _exchange(_Orders orders, List<ExchangeEnvironment> environments) =>
    exchangeForTesting(
      orders: (environment) {
        environments.add(environment);
        return orders;
      },
    );

const _journal = OrderCreateJournalRequest(
  type: OrderType.withdraw,
  amount: FiatAmount(10),
);

/// withdrawOrder() is created at 2026-11-24 00:00 UTC for 10 CAD.
final _sentAt = DateTime.utc(2026, 11, 24);

void main() {
  test('finds the order the create made among orders of the journaled '
      'type', () async {
    final environments = <ExchangeEnvironment>[];
    final orders = _Orders(list: Ok([withdrawOrder()]));
    final read = await FindCreatedOrderUsecase(_exchange(orders, environments))
        .execute<WithdrawOrder>(_session, _journal, _sentAt);
    expect(
      read,
      isA<ReadGot<WithdrawOrder>>().having(
        (r) => r.value.orderId,
        'orderId',
        'w-1',
      ),
    );
    expect(orders.asked, ['list withdraw']);
    expect(environments, [ExchangeEnvironment.testnet]);
  });

  test('no order created around the send is missing', () async {
    final read =
        await FindCreatedOrderUsecase(
          _exchange(_Orders(list: Ok([withdrawOrder()])), []),
        ).execute<WithdrawOrder>(
          _session,
          _journal,
          _sentAt.add(const Duration(days: 2)),
        );
    expect(read, isA<ReadMissing<WithdrawOrder>>());
  });

  test('a match of another order class is missing', () async {
    final read = await FindCreatedOrderUsecase(
      _exchange(_Orders(list: Ok([withdrawOrder()])), []),
    ).execute<BuyOrder>(_session, _journal, _sentAt);
    expect(read, isA<ReadMissing<BuyOrder>>());
  });

  test('a failed listing is never read as no order', () async {
    final read = await FindCreatedOrderUsecase(
      _exchange(_Orders(list: const Err(ExchangeNetworkFailure())), []),
    ).execute<WithdrawOrder>(_session, _journal, _sentAt);
    expect(read, isA<ReadUnreachable<WithdrawOrder>>());
  });
}
