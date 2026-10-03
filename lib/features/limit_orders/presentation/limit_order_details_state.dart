import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';

final class LimitOrderDetailsState {
  final LimitOrder? order;
  final bool isLoading;
  final bool isCancelling;
  final bool wasCancelled;
  final LimitOrdersFailure? failure;

  const LimitOrderDetailsState({
    this.order,
    this.isLoading = false,
    this.isCancelling = false,
    this.wasCancelled = false,
    this.failure,
  });

  LimitOrderDetailsState copyWith({
    LimitOrder? order,
    bool? isLoading,
    bool? isCancelling,
    bool? wasCancelled,
    LimitOrdersFailure? failure,
    bool clearFailure = false,
  }) => LimitOrderDetailsState(
    order: order ?? this.order,
    isLoading: isLoading ?? this.isLoading,
    isCancelling: isCancelling ?? this.isCancelling,
    wasCancelled: wasCancelled ?? this.wasCancelled,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
