/// Entity for amount with currency
class AmountByCurrencyCode {
  final String currency;
  final double value;

  const AmountByCurrencyCode({
    required this.currency,
    required this.value,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AmountByCurrencyCode &&
        other.currency == currency &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(currency, value);
}

/// Entity for order statistics
class OrderStats {
  final List<AmountByCurrencyCode> bitcoinBuyVolume;
  final List<AmountByCurrencyCode> bitcoinBuyTradeCount;
  final List<AmountByCurrencyCode> averageBitcoinBuyPrice;
  final List<AmountByCurrencyCode> bitcoinSellVolume;
  final List<AmountByCurrencyCode> bitcoinSellTradeCount;
  final List<AmountByCurrencyCode> averageBitcoinSellPrice;
  final List<AmountByCurrencyCode> totalBitcoinTradingVolume;
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

/// Entity for individual biller stat
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

  String get displayName {
    if (billerName.isNotEmpty && billerCode.isNotEmpty) {
      return '$billerName - $billerCode';
    }
    return billerName.isNotEmpty ? billerName : billerCode;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BillerStat &&
        other.billerName == billerName &&
        other.billerCode == billerCode &&
        other.totalAmount == totalAmount &&
        other.tradeCount == tradeCount;
  }

  @override
  int get hashCode =>
      Object.hash(billerName, billerCode, totalAmount, tradeCount);
}

/// Entity for biller statistics
class BillerStats {
  final String currency;
  final List<BillerStat> stats;

  const BillerStats({
    required this.currency,
    required this.stats,
  });

  bool get hasStats => stats.isNotEmpty;
}

/// Entity for complete order stats response
class OrderStatsResponse {
  final OrderStats orderStats;
  final BillerStats billerStats;
  final DateTime asOf;

  const OrderStatsResponse({
    required this.orderStats,
    required this.billerStats,
    required this.asOf,
  });
}
