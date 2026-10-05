import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:meta/meta.dart';

class GetLimitOrderRateUsecase {
  final LimitOrderRepository _repository;

  const GetLimitOrderRateUsecase(this._repository);

  @useResult
  Future<Result<LimitOrderRate, LimitOrdersFailure>> execute(
    String currencyCode,
  ) => _repository.getRate(currencyCode);
}
