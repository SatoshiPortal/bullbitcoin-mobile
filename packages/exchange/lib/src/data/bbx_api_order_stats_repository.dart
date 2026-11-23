import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

import '../domain/entities/order_stats.dart';
import '../domain/exchange_failure.dart';

final class BbxApiOrderStatsRepository {
  final bbx.Bbx _api;

  const BbxApiOrderStatsRepository({required this._api});

  Future<Result<OrderStatistics, ExchangeFailure>> getOrderStats() async {
    final result = await _api.orders.getOrderStats();
    return switch (result) {
      Ok(:final value) => Ok(_toEntity(value)),
      Err(failure: bbx.BbxMissingCredentialFailure()) => const Err(
        ExchangeNotAuthenticatedFailure(),
      ),
      Err(failure: bbx.BbxCredentialUnavailableFailure()) => const Err(
        ExchangeCredentialReadFailure(),
      ),
      Err(:final failure) => Err(
        ExchangeStatisticsUnavailableFailure(
          'Failed to get order stats: ${failure.runtimeType}',
        ),
      ),
    };
  }

  static OrderStatistics _toEntity(bbx.OrderStatsReport report) {
    List<AmountByCurrencyCode> amounts(List<bbx.CurrencyAmount> wire) => [
      for (final a in wire)
        AmountByCurrencyCode(currency: a.currency, value: a.value),
    ];
    final orders = report.orderStats;
    final billers = report.billerStats;
    return OrderStatistics(
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
