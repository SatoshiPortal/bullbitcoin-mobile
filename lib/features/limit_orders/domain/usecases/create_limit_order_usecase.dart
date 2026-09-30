import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:meta/meta.dart';

class CreateLimitOrderUsecase {
  final LimitOrderRepository _repository;

  const CreateLimitOrderUsecase(this._repository);

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

    final rateResult = await _repository.getRate(currency.code);
    switch (rateResult) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (limitPrice >= value.indexPrice) {
          return const Err(
            LimitOrderInvalidTargetFailure(
              'target at or above the index price',
            ),
          );
        }
        return _repository.create(
          LimitOrderDraft(
            limitPrice: limitPrice,
            fiatAmount: fiatAmount,
            currencyCode: currency.code,
            address: trimmedAddress,
          ),
        );
    }
  }
}
