import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:meta/meta.dart';

class ListActiveLimitOrdersUsecase {
  final LimitOrderRepository _repository;

  const ListActiveLimitOrdersUsecase(this._repository);

  @useResult
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> execute() =>
      _repository.listActive();
}
