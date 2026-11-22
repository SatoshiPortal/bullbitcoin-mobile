import 'package:meta/meta.dart';

/// The result of `getOrderStats`.
@immutable
class OrderStatsReport {
  final OrderStats orderStats;
  final BillerStats billerStats;
  final DateTime asOf;

  const OrderStatsReport({
    required this.orderStats,
    required this.billerStats,
    required this.asOf,
  });
}

@immutable
class OrderStats {
  final List<CurrencyAmount> bitcoinBuyVolume;
  final List<CurrencyAmount> bitcoinBuyTradeCount;
  final List<CurrencyAmount> averageBitcoinBuyPrice;
  final List<CurrencyAmount> bitcoinSellVolume;
  final List<CurrencyAmount> bitcoinSellTradeCount;
  final List<CurrencyAmount> averageBitcoinSellPrice;
  final List<CurrencyAmount> totalBitcoinTradingVolume;

  /// `buy:sell`, `0:0` when the server omits it.
  final String buySellRatio;

  const OrderStats({
    required this.bitcoinBuyVolume,
    required this.bitcoinBuyTradeCount,
    required this.averageBitcoinBuyPrice,
    required this.bitcoinSellVolume,
    required this.bitcoinSellTradeCount,
    required this.averageBitcoinSellPrice,
    required this.totalBitcoinTradingVolume,
    required this.buySellRatio,
  });
}

@immutable
class CurrencyAmount {
  final String currency;
  final double value;

  const CurrencyAmount({required this.currency, required this.value});
}

@immutable
class BillerStats {
  final String currency;
  final List<BillerStat> stats;

  const BillerStats({required this.currency, required this.stats});
}

@immutable
class BillerStat {
  final String billerName;
  final String billerCode;
  final double totalAmount;
  final int tradeCount;

  const BillerStat({
    required this.billerName,
    required this.billerCode,
    required this.totalAmount,
    required this.tradeCount,
  });
}
