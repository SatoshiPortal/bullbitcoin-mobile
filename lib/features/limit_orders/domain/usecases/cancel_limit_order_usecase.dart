import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:meta/meta.dart';

class CancelLimitOrderUsecase {
  final LimitOrderRepository _repository;

  const CancelLimitOrderUsecase(this._repository);

  @useResult
  Future<Result<LimitOrder, LimitOrdersFailure>> execute(String id) =>
      _repository.cancel(id);
}
