import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_stats_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;

/// Order statistics through the `bbx_api` package.
class BbxApiOrderStatsRepository implements ExchangeOrderStatsRepository {
  final bbx.BbxApiClient _api;

  BbxApiOrderStatsRepository({required this._api});

  @override
  Future<OrderStatsResponse> getOrderStats() async {
    try {
      return _toEntity(await _api.orders.getOrderStats());
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      if (e is ApiKeyException) rethrow;
      throw Exception('Failed to get order stats: $e');
    }
  }

  static OrderStatsResponse _toEntity(bbx.OrderStatsReport report) {
    List<AmountByCurrencyCode> amounts(List<bbx.CurrencyAmount> wire) => [
      for (final a in wire)
        AmountByCurrencyCode(currency: a.currency, value: a.value),
    ];
    final orders = report.orderStats;
    final billers = report.billerStats;
    return OrderStatsResponse(
      orderStats: OrderStats(
        bitcoinBuyVolume: amounts(orders.bitcoinBuyVolume),
        bitcoinBuyTradeCount: amounts(orders.bitcoinBuyTradeCount),
        averageBitcoinBuyPrice: amounts(orders.averageBitcoinBuyPrice),
        bitcoinSellVolume: amounts(orders.bitcoinSellVolume),
        bitcoinSellTradeCount: amounts(orders.bitcoinSellTradeCount),
        averageBitcoinSellPrice: amounts(orders.averageBitcoinSellPrice),
        totalBitcoinTradingVolume: amounts(orders.totalBitcoinTradingVolume),
        buySellRatio: orders.buySellRatio,
      ),
      billerStats: BillerStats(
        currency: billers.currency,
        stats: [
          for (final s in billers.stats)
            BillerStat(
              billerName: s.billerName,
              billerCode: s.billerCode,
              totalAmount: s.totalAmount,
              tradeCount: s.tradeCount,
            ),
        ],
      ),
      asOf: report.asOf,
    );
  }
}
