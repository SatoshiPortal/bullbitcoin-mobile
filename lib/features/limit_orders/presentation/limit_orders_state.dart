import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';

final class LimitOrdersState {
  final List<LimitOrder> orders;
  final bool canCreate;
  final bool isLoading;
  final bool isCancellingAll;
  final LimitOrdersFailure? failure;

  const LimitOrdersState({
    this.orders = const [],
    this.canCreate = true,
    this.isLoading = false,
    this.isCancellingAll = false,
    this.failure,
  });

  LimitOrdersState copyWith({
    List<LimitOrder>? orders,
    bool? canCreate,
    bool? isLoading,
    bool? isCancellingAll,
    LimitOrdersFailure? failure,
    bool clearFailure = false,
  }) => LimitOrdersState(
    orders: orders ?? this.orders,
    canCreate: canCreate ?? this.canCreate,
    isLoading: isLoading ?? this.isLoading,
    isCancellingAll: isCancellingAll ?? this.isCancellingAll,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
