import 'package:bb_mobile/core/exchange/data/exchange_json_decoder.dart';
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
        decodeExchangeJson<Map<String, dynamic>>(json['orderStats']),
      ),
      billerStats: BillerStatsModel.fromJson(
        decodeExchangeJson<Map<String, dynamic>>(json['billerStats']),
      ),
      asOf: DateTime.parse(decodeExchangeJson<String>(json['asOf'])),
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
      averageBitcoinSellPrice: _parseAmountList(
        json['averageBitcoinSellPrice'],
      ),
      totalBitcoinTradingVolume: _parseAmountList(
        json['totalBitcoinTradingVolume'],
      ),
      buySellRatio: decodeExchangeJson<String?>(json['buySellRatio']) ?? '0:0',
    );
  }

  static List<AmountByCurrencyCodeModel> _parseAmountList(dynamic list) {
    if (list == null) return [];
    return decodeExchangeJson<List<dynamic>>(list)
        .map(
          (e) => AmountByCurrencyCodeModel.fromJson(
            decodeExchangeJson<Map<String, dynamic>>(e),
          ),
        )
        .toList();
  }

  OrderStats toEntity() {
    return OrderStats(
      bitcoinBuyVolume: bitcoinBuyVolume.map((e) => e.toEntity()).toList(),
      bitcoinBuyTradeCount: bitcoinBuyTradeCount
          .map((e) => e.toEntity())
          .toList(),
      averageBitcoinBuyPrice: averageBitcoinBuyPrice
          .map((e) => e.toEntity())
          .toList(),
      bitcoinSellVolume: bitcoinSellVolume.map((e) => e.toEntity()).toList(),
      bitcoinSellTradeCount: bitcoinSellTradeCount
          .map((e) => e.toEntity())
          .toList(),
      averageBitcoinSellPrice: averageBitcoinSellPrice
          .map((e) => e.toEntity())
          .toList(),
      totalBitcoinTradingVolume: totalBitcoinTradingVolume
          .map((e) => e.toEntity())
          .toList(),
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
      currency: decodeExchangeJson<String>(json['currency']),
      value: (decodeExchangeJson<num>(json['value'])).toDouble(),
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

  const BillerStatsModel({required this.currency, required this.stats});

  factory BillerStatsModel.fromJson(Map<String, dynamic> json) {
    return BillerStatsModel(
      currency: decodeExchangeJson<String?>(json['currency']) ?? '',
      stats: _parseStatsList(json['stats']),
    );
  }

  static List<BillerStatModel> _parseStatsList(dynamic list) {
    if (list == null) return [];
    return decodeExchangeJson<List<dynamic>>(list)
        .map(
          (e) => BillerStatModel.fromJson(
            decodeExchangeJson<Map<String, dynamic>>(e),
          ),
        )
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
      billerName: decodeExchangeJson<String?>(json['billerName']) ?? '',
      billerCode: decodeExchangeJson<String?>(json['billerCode']) ?? '',
      totalAmount:
          (decodeExchangeJson<num?>(json['totalAmount']))?.toDouble() ?? 0.0,
      tradeCount: decodeExchangeJson<int?>(json['tradeCount']) ?? 0,
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
