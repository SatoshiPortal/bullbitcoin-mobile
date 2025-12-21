import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';

class StatValueModel {
  final double amount;
  final String currencyCode;

  StatValueModel({
    required this.amount,
    required this.currencyCode,
  });

  factory StatValueModel.fromJson(Map<String, dynamic> json) {
    return StatValueModel(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currencyCode'] as String? ?? '',
    );
  }

  StatValue toEntity() {
    return StatValue(
      amount: amount,
      currencyCode: currencyCode,
    );
  }
}

class BillerStatsModel {
  final String billerName;
  final int orderCount;
  final double totalAmount;
  final String currencyCode;

  BillerStatsModel({
    required this.billerName,
    required this.orderCount,
    required this.totalAmount,
    required this.currencyCode,
  });

  factory BillerStatsModel.fromJson(Map<String, dynamic> json) {
    return BillerStatsModel(
      billerName: json['billerName'] as String? ?? '',
      orderCount: json['orderCount'] as int? ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currencyCode'] as String? ?? '',
    );
  }

  BillerStats toEntity() {
    return BillerStats(
      billerName: billerName,
      orderCount: orderCount,
      totalAmount: totalAmount,
      currencyCode: currencyCode,
    );
  }
}

class OrderStatsModel {
  final String asOf;
  final List<StatValueModel> bitcoinBuyVolume;
  final List<StatValueModel> bitcoinSellVolume;
  final int buyTradeCount;
  final int sellTradeCount;
  final List<StatValueModel> averageBuyPrice;
  final List<StatValueModel> averageSellPrice;
  final List<BillerStatsModel> paidBillers;

  OrderStatsModel({
    required this.asOf,
    required this.bitcoinBuyVolume,
    required this.bitcoinSellVolume,
    required this.buyTradeCount,
    required this.sellTradeCount,
    required this.averageBuyPrice,
    required this.averageSellPrice,
    required this.paidBillers,
  });

  factory OrderStatsModel.fromJson(Map<String, dynamic> json) {
    return OrderStatsModel(
      asOf: json['asOf'] as String? ?? DateTime.now().toIso8601String(),
      bitcoinBuyVolume: (json['bitcoinBuyVolume'] as List<dynamic>?)
              ?.map((e) => StatValueModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      bitcoinSellVolume: (json['bitcoinSellVolume'] as List<dynamic>?)
              ?.map((e) => StatValueModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      buyTradeCount: json['buyTradeCount'] as int? ?? 0,
      sellTradeCount: json['sellTradeCount'] as int? ?? 0,
      averageBuyPrice: (json['averageBuyPrice'] as List<dynamic>?)
              ?.map((e) => StatValueModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      averageSellPrice: (json['averageSellPrice'] as List<dynamic>?)
              ?.map((e) => StatValueModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      paidBillers: (json['paidBillers'] as List<dynamic>?)
              ?.map((e) => BillerStatsModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  OrderStats toEntity() {
    return OrderStats(
      asOf: DateTime.tryParse(asOf) ?? DateTime.now(),
      bitcoinBuyVolume: bitcoinBuyVolume.map((e) => e.toEntity()).toList(),
      bitcoinSellVolume: bitcoinSellVolume.map((e) => e.toEntity()).toList(),
      buyTradeCount: buyTradeCount,
      sellTradeCount: sellTradeCount,
      averageBuyPrice: averageBuyPrice.map((e) => e.toEntity()).toList(),
      averageSellPrice: averageSellPrice.map((e) => e.toEntity()).toList(),
      paidBillers: paidBillers.map((e) => e.toEntity()).toList(),
    );
  }
}






