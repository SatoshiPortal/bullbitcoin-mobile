import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_orders_failure.dart';
import 'package:meta/meta.dart';

import '../map_limit_order_failure.dart';

class CreateLimitOrderUsecase {
  final ExchangeLimitOrders _orders;

  const CreateLimitOrderUsecase(this._orders);

  @useResult
  Future<Result<LimitOrder, LimitOrdersFailure>> execute({
    required double limitPrice,
    required double fiatAmount,
    required FiatCurrency currency,
    required String address,
  }) async {
    final trimmedAddress = address.trim();
    if (trimmedAddress.isEmpty) {
      return const Err(LimitOrderInvalidAddressFailure('missing address'));
    }
    if (fiatAmount <= 0) {
      return const Err(LimitOrderInvalidAmountFailure('non-positive amount'));
    }
    if (limitPrice <= 0) {
      return const Err(LimitOrderInvalidTargetFailure('non-positive target'));
    }

    final rateResult = await _orders.getRate(currency.code);
    switch (rateResult) {
      case Err(:final failure):
        return Err(mapLimitOrderFailure(failure));
      case Ok(:final value):
        if (limitPrice >= value.indexPrice) {
          return const Err(
            LimitOrderInvalidTargetFailure(
              'target at or above the index price',
            ),
          );
        }
        return (await _orders.create(
          LimitOrderDraft(
            limitPrice: limitPrice,
            fiatAmount: fiatAmount,
            currency: currency,
            address: trimmedAddress,
          ),
        )).mapErr(mapLimitOrderFailure);
    }
  }
}
