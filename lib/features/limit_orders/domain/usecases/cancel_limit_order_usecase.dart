import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:meta/meta.dart';

import '../map_limit_order_failure.dart';

class CancelLimitOrderUsecase {
  final ExchangeLimitOrders _orders;

  const CancelLimitOrderUsecase(this._orders);

  @useResult
  Future<Result<LimitOrder, LimitOrdersFailure>> execute(String id) async =>
      (await _orders.cancel(id)).mapErr(mapLimitOrderFailure);
}
