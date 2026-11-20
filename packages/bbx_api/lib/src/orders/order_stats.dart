import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
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

  factory OrderStatsReport.fromJson(Map<String, dynamic> json) {
    final asOf = DateTime.tryParse(read<String>(json['asOf'], 'asOf'));
    if (asOf == null) throw const BbxApiFormatException('invalid asOf');
    return OrderStatsReport(
      orderStats: OrderStats.fromJson(
        read<Map<String, dynamic>>(json['orderStats'], 'orderStats'),
      ),
      billerStats: BillerStats.fromJson(
        read<Map<String, dynamic>>(json['billerStats'], 'billerStats'),
      ),
      asOf: asOf,
    );
  }
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

  factory OrderStats.fromJson(Map<String, dynamic> json) {
    List<CurrencyAmount> amounts(String field) =>
        readList(json[field], field, CurrencyAmount.fromJson);
    return OrderStats(
      bitcoinBuyVolume: amounts('bitcoinBuyVolume'),
      bitcoinBuyTradeCount: amounts('bitcoinBuyTradeCount'),
      averageBitcoinBuyPrice: amounts('averageBitcoinBuyPrice'),
      bitcoinSellVolume: amounts('bitcoinSellVolume'),
      bitcoinSellTradeCount: amounts('bitcoinSellTradeCount'),
      averageBitcoinSellPrice: amounts('averageBitcoinSellPrice'),
      totalBitcoinTradingVolume: amounts('totalBitcoinTradingVolume'),
      buySellRatio:
          read<String?>(json['buySellRatio'], 'buySellRatio') ?? '0:0',
    );
  }
}

@immutable
class CurrencyAmount {
  final String currency;
  final double value;

  const CurrencyAmount({required this.currency, required this.value});

  factory CurrencyAmount.fromJson(Map<String, dynamic> json) => CurrencyAmount(
    currency: read<String>(json['currency'], 'currency'),
    value: read<num>(json['value'], 'value').toDouble(),
  );
}

@immutable
class BillerStats {
  final String currency;
  final List<BillerStat> stats;

  const BillerStats({required this.currency, required this.stats});

  factory BillerStats.fromJson(Map<String, dynamic> json) => BillerStats(
    currency: read<String?>(json['currency'], 'currency') ?? '',
    stats: readList(json['stats'], 'stats', BillerStat.fromJson),
  );
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

  factory BillerStat.fromJson(Map<String, dynamic> json) => BillerStat(
    billerName: read<String?>(json['billerName'], 'billerName') ?? '',
    billerCode: read<String?>(json['billerCode'], 'billerCode') ?? '',
    totalAmount:
        read<num?>(json['totalAmount'], 'totalAmount')?.toDouble() ?? 0.0,
    tradeCount: read<int?>(json['tradeCount'], 'tradeCount') ?? 0,
  );
}
