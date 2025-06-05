import 'package:bb_mobile/core/exchange/domain/entity/order.dart';

abstract class ExchangeOrderRepository {
  Future<BuyOrder> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required Network network,
    required String isOwner,
  });
  Future<Order> getOrder(String orderId);
  Future<List<Order>> getOrders({int? limit, int? offset, OrderType? type});
}
