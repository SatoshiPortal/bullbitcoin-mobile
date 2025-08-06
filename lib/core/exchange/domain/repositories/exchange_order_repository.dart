import 'package:bb_mobile/core/exchange/domain/entity/order.dart';

abstract class ExchangeOrderRepository {
  Future<BuyOrder> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    required bool isOwner,
  });
  Future<SellOrder> placeSellOrder({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
  });
  Future<FiatPaymentOrder> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required String paymentProcessor,
    required OrderBitcoinNetwork network,
  });
  Future<WithdrawOrder> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    required String paymentProcessor,
  });
  Future<BuyOrder> confirmBuyOrder(String orderId);
  Future<WithdrawOrder> confirmWithdrawOrder(String orderId);
  Future<BuyOrder> refreshBuyOrder(String orderId);
  Future<SellOrder> refreshSellOrder(String orderId);
  Future<BuyOrder> accelerateBuyOrder(String orderId);
  Future<Order> getOrder(String orderId);
  Future<Order?> getOrderByTxId(String txId);
  Future<List<Order>> getOrders({int? limit, int? offset, OrderType? type});
}
