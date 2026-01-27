import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'statistics_state.freezed.dart';

@freezed
abstract class StatisticsState with _$StatisticsState {
  const factory StatisticsState({
    OrderStatsResponse? stats,
    @Default(false) bool isLoading,
    String? error,
  }) = _StatisticsState;

  const StatisticsState._();

  bool get hasStats => stats != null;

  OrderStats? get orderStats => stats?.orderStats;
  BillerStats? get billerStats => stats?.billerStats;
  DateTime? get asOf => stats?.asOf;

  // Formatted buy stats
  List<String> get formattedBuyVolume =>
      _formatAmounts(orderStats?.bitcoinBuyVolume);

  List<String> get formattedBuyTradeCount =>
      _formatTradeCounts(orderStats?.bitcoinBuyTradeCount);

  List<String> get formattedAvgBuyPrice =>
      _formatAmounts(orderStats?.averageBitcoinBuyPrice);

  // Formatted sell stats
  List<String> get formattedSellVolume =>
      _formatAmounts(orderStats?.bitcoinSellVolume);

  List<String> get formattedSellTradeCount =>
      _formatTradeCounts(orderStats?.bitcoinSellTradeCount);

  List<String> get formattedAvgSellPrice =>
      _formatAmounts(orderStats?.averageBitcoinSellPrice);

  // Formatted total volume
  List<String> get formattedTotalVolume =>
      _formatAmounts(orderStats?.totalBitcoinTradingVolume);

  // Formatted biller stats
  List<FormattedBillerStat> get formattedBillerStats {
    final stats = billerStats;
    if (stats == null || !stats.hasStats) return [];

    return stats.stats
        .map(
          (stat) => FormattedBillerStat(
            displayName: stat.displayName,
            formattedAmount: FormatAmount.fiat(stat.totalAmount, stats.currency),
            tradeCount: stat.tradeCount,
          ),
        )
        .toList();
  }

  List<String> _formatAmounts(List<AmountByCurrencyCode>? amounts) {
    if (amounts == null || amounts.isEmpty) return ['0'];

    return amounts
        .map((a) => FormatAmount.fiat(a.value, a.currency))
        .toList();
  }

  List<String> _formatTradeCounts(List<AmountByCurrencyCode>? counts) {
    if (counts == null || counts.isEmpty) return ['0 trades'];

    return counts
        .map((c) => '${c.value.toInt()} trades (${c.currency})')
        .toList();
  }
}

/// Formatted biller stat for display
class FormattedBillerStat {
  final String displayName;
  final String formattedAmount;
  final int tradeCount;

  const FormattedBillerStat({
    required this.displayName,
    required this.formattedAmount,
    required this.tradeCount,
  });
}
