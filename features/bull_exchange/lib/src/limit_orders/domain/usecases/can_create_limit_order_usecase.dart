import 'package:exchange/exchange.dart';

final class CanCreateLimitOrderUsecase {
  static const maximumActiveOrders = 5;

  const CanCreateLimitOrderUsecase();

  bool execute(List<LimitOrder> activeOrders) =>
      activeOrders.length < maximumActiveOrders;
}
