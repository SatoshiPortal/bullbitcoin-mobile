import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:meta/meta.dart';

abstract interface class LimitOrderRepository {
  @useResult
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> listActive();

  @useResult
  Future<Result<LimitOrder, LimitOrdersFailure>> get(String id);

  @useResult
  Future<Result<LimitOrder, LimitOrdersFailure>> create(LimitOrderDraft draft);

  @useResult
  Future<Result<LimitOrder, LimitOrdersFailure>> cancel(String id);

  @useResult
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> cancelAll();

  @useResult
  Future<Result<LimitOrderRate, LimitOrdersFailure>> getRate(
    String currencyCode,
  );
}
