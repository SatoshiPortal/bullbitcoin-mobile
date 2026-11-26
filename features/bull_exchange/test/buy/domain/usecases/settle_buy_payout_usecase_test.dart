import 'package:bull_exchange/src/buy/domain/usecases/settle_buy_payout_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../buy_fixtures.dart';

void main() {
  late List<String> log;
  late SettleBuyPayoutUsecase settle;

  setUp(() {
    log = [];
    settle = SettleBuyPayoutUsecase(
      (orders) async => log.add('label ${orders.map((o) => o.orderId)}'),
      (walletId) async => log.add('poll $walletId'),
    );
  });

  test('a completed order writes its labels and the wallet syncs', () async {
    await settle.execute(buyOrder(status: OrderStatus.completed), 'w-lq');
    expect(log, ['label (b-1)', 'poll w-lq']);
  });

  test('an order not completed writes no labels (#2624)', () async {
    await settle.execute(buyOrder(status: OrderStatus.inProgress), 'w-lq');
    expect(log, ['poll w-lq']);
  });

  test('a typed address has no wallet to sync', () async {
    await settle.execute(buyOrder(status: OrderStatus.inProgress), null);
    expect(log, isEmpty);
  });
}
