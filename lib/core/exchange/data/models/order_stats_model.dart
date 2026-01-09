import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';

/// Model for the complete order stats API response
class OrderStatsResponseModel {
  final OrderStatsModel orderStats;
  final BillerStatsModel billerStats;
  final DateTime asOf;

  const OrderStatsResponseModel({
    required this.orderStats,
    required this.billerStats,
    required this.asOf,
  });

  factory OrderStatsResponseModel.fromJson(Map<String, dynamic> json) {
    return OrderStatsResponseModel(
      orderStats: OrderStatsModel.fromJson(
        json['orderStats'] as Map<String, dynamic>,
      ),
      billerStats: BillerStatsModel.fromJson(
        json['billerStats'] as Map<String, dynamic>,
      ),
      asOf: DateTime.parse(json['asOf'] as String),
    );
  }

  OrderStatsResponse toEntity() {
    return OrderStatsResponse(
      orderStats: orderStats.toEntity(),
      billerStats: billerStats.toEntity(),
      asOf: asOf,
    );
  }
}

/// Model for order statistics
class OrderStatsModel {
  final List<AmountByCurrencyCodeModel> bitcoinBuyVolume;
  final List<AmountByCurrencyCodeModel> bitcoinBuyTradeCount;
  final List<AmountByCurrencyCodeModel> averageBitcoinBuyPrice;
  final List<AmountByCurrencyCodeModel> bitcoinSellVolume;
  final List<AmountByCurrencyCodeModel> bitcoinSellTradeCount;
  final List<AmountByCurrencyCodeModel> averageBitcoinSellPrice;
  final List<AmountByCurrencyCodeModel> totalBitcoinTradingVolume;
  final String buySellRatio;

  const OrderStatsModel({
    required this.bitcoinBuyVolume,
    required this.bitcoinBuyTradeCount,
    required this.averageBitcoinBuyPrice,
    required this.bitcoinSellVolume,
    required this.bitcoinSellTradeCount,
    required this.averageBitcoinSellPrice,
    required this.totalBitcoinTradingVolume,
    required this.buySellRatio,
  });

  factory OrderStatsModel.fromJson(Map<String, dynamic> json) {
    return OrderStatsModel(
      bitcoinBuyVolume: _parseAmountList(json['bitcoinBuyVolume']),
      bitcoinBuyTradeCount: _parseAmountList(json['bitcoinBuyTradeCount']),
      averageBitcoinBuyPrice: _parseAmountList(json['averageBitcoinBuyPrice']),
      bitcoinSellVolume: _parseAmountList(json['bitcoinSellVolume']),
      bitcoinSellTradeCount: _parseAmountList(json['bitcoinSellTradeCount']),
      averageBitcoinSellPrice: _parseAmountList(json['averageBitcoinSellPrice']),
      totalBitcoinTradingVolume: _parseAmountList(
        json['totalBitcoinTradingVolume'],
      ),
      buySellRatio: json['buySellRatio'] as String? ?? '0:0',
    );
  }

  static List<AmountByCurrencyCodeModel> _parseAmountList(dynamic list) {
    if (list == null) return [];
    return (list as List)
        .map(
          (e) => AmountByCurrencyCodeModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  OrderStats toEntity() {
    return OrderStats(
      bitcoinBuyVolume: bitcoinBuyVolume.map((e) => e.toEntity()).toList(),
      bitcoinBuyTradeCount:
          bitcoinBuyTradeCount.map((e) => e.toEntity()).toList(),
      averageBitcoinBuyPrice:
          averageBitcoinBuyPrice.map((e) => e.toEntity()).toList(),
      bitcoinSellVolume: bitcoinSellVolume.map((e) => e.toEntity()).toList(),
      bitcoinSellTradeCount:
          bitcoinSellTradeCount.map((e) => e.toEntity()).toList(),
      averageBitcoinSellPrice:
          averageBitcoinSellPrice.map((e) => e.toEntity()).toList(),
      totalBitcoinTradingVolume:
          totalBitcoinTradingVolume.map((e) => e.toEntity()).toList(),
      buySellRatio: buySellRatio,
    );
  }
}

/// Model for amount with currency
class AmountByCurrencyCodeModel {
  final String currency;
  final double value;

  const AmountByCurrencyCodeModel({
    required this.currency,
    required this.value,
  });

  factory AmountByCurrencyCodeModel.fromJson(Map<String, dynamic> json) {
    return AmountByCurrencyCodeModel(
      currency: json['currency'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }

  AmountByCurrencyCode toEntity() {
    return AmountByCurrencyCode(currency: currency, value: value);
  }
}

/// Model for biller statistics
class BillerStatsModel {
  final String currency;
  final List<BillerStatModel> stats;

  const BillerStatsModel({
    required this.currency,
    required this.stats,
  });

  factory BillerStatsModel.fromJson(Map<String, dynamic> json) {
    return BillerStatsModel(
      currency: json['currency'] as String? ?? '',
      stats: _parseStatsList(json['stats']),
    );
  }

  static List<BillerStatModel> _parseStatsList(dynamic list) {
    if (list == null) return [];
    return (list as List)
        .map((e) => BillerStatModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  BillerStats toEntity() {
    return BillerStats(
      currency: currency,
      stats: stats.map((e) => e.toEntity()).toList(),
    );
  }
}

/// Model for individual biller stat
class BillerStatModel {
  final String billerName;
  final String billerCode;
  final double totalAmount;
  final int tradeCount;

  const BillerStatModel({
    required this.billerName,
    required this.billerCode,
    required this.totalAmount,
    required this.tradeCount,
  });

  factory BillerStatModel.fromJson(Map<String, dynamic> json) {
    return BillerStatModel(
      billerName: json['billerName'] as String? ?? '',
      billerCode: json['billerCode'] as String? ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      tradeCount: json['tradeCount'] as int? ?? 0,
    );
  }

  BillerStat toEntity() {
    return BillerStat(
      billerName: billerName,
      billerCode: billerCode,
      totalAmount: totalAmount,
      tradeCount: tradeCount,
    );
  }
}

