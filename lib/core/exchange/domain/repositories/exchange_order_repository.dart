import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';

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
    required OrderBitcoinNetwork network,
  });
  Future<WithdrawOrder> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    bool isETransfer = false,
  });
  Future<BuyOrder> confirmBuyOrder(String orderId);
  Future<WithdrawOrder> confirmWithdrawOrder(String orderId);
  Future<BuyOrder> refreshBuyOrder(String orderId);
  Future<SellOrder> refreshSellOrder(String orderId);
  Future<FiatPaymentOrder> refreshPayOrder(String orderId);
  Future<BuyOrder> accelerateBuyOrder(String orderId);
  Future<Order> getOrder(String orderId);
  Future<Order?> getOrderByTxId(String txId);
  Future<List<Order>> getOrders({int? limit, int? offset, OrderType? type});
  Future<Dca> createDca({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required DcaNetwork network,
    required String address,
  });
  Future<Map<String, dynamic>> getBuyLimits();
  Future<Map<String, dynamic>> getSellLimits();
}
