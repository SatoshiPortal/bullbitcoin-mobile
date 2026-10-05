import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';

final class CanCreateLimitOrderUsecase {
  static const maximumActiveOrders = 5;

  const CanCreateLimitOrderUsecase();

  bool execute(List<LimitOrder> activeOrders) =>
      activeOrders.length < maximumActiveOrders;
}
