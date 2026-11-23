import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:meta/meta.dart';

import '../map_limit_order_failure.dart';

class GetLimitOrderRateUsecase {
  final ExchangeLimitOrders _orders;

  const GetLimitOrderRateUsecase(this._orders);

  @useResult
  Future<Result<LimitOrderRate, LimitOrdersFailure>> execute(
    String currencyCode,
  ) async => (await _orders.getRate(currencyCode)).mapErr(mapLimitOrderFailure);
}
