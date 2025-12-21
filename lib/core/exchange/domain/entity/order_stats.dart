import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_stats.freezed.dart';

/// Represents a statistical value with amount and currency
@freezed
sealed class StatValue with _$StatValue {
  const StatValue._();

  const factory StatValue({
    required double amount,
    required String currencyCode,
  }) = _StatValue;

  String get formattedAmount {
    if (currencyCode == 'BTC') {
      return '${amount.toStringAsFixed(8)} $currencyCode';
    }
    return '${amount.toStringAsFixed(2)} $currencyCode';
  }
}

/// Represents aggregated order statistics for the user
@freezed
sealed class OrderStats with _$OrderStats {
  const OrderStats._();

  const factory OrderStats({
    required DateTime asOf,
    @Default([]) List<StatValue> bitcoinBuyVolume,
    @Default([]) List<StatValue> bitcoinSellVolume,
    @Default(0) int buyTradeCount,
    @Default(0) int sellTradeCount,
    @Default([]) List<StatValue> averageBuyPrice,
    @Default([]) List<StatValue> averageSellPrice,
    @Default([]) List<BillerStats> paidBillers,
  }) = _OrderStats;

  /// Total number of trades (buy + sell)
  int get totalTradeCount => buyTradeCount + sellTradeCount;

  /// Buy/Sell ratio as a percentage string
  String get buySellRatio {
    if (totalTradeCount == 0) return 'N/A';
    final ratio = (buyTradeCount / totalTradeCount) * 100;
    return '${ratio.toStringAsFixed(1)}% Buy / ${(100 - ratio).toStringAsFixed(1)}% Sell';
  }
}

/// Represents statistics for a specific biller
@freezed
sealed class BillerStats with _$BillerStats {
  const BillerStats._();

  const factory BillerStats({
    required String billerName,
    required int orderCount,
    required double totalAmount,
    required String currencyCode,
  }) = _BillerStats;
}

