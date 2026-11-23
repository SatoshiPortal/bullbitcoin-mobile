import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:meta/meta.dart';

import '../map_limit_order_failure.dart';

class ListActiveLimitOrdersUsecase {
  final ExchangeLimitOrders _orders;

  const ListActiveLimitOrdersUsecase(this._orders);

  @useResult
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> execute() async =>
      (await _orders.listActive()).mapErr(mapLimitOrderFailure);
}
