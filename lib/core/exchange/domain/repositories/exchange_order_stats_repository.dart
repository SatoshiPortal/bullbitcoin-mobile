import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';

abstract class ExchangeOrderStatsRepository {
  /// Get order statistics for the current user
  Future<OrderStatsResponse> getOrderStats();
}

