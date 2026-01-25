import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_stats_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StatisticsCubit extends Cubit<StatisticsState> {
  StatisticsCubit({
    required GetOrderStatsUsecase getOrderStatsUsecase,
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required ExchangeRateRepository exchangeRateRepository,
  }) : _getOrderStatsUsecase = getOrderStatsUsecase,
       _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _exchangeRateRepository = exchangeRateRepository,
       super(const StatisticsState());

  final GetOrderStatsUsecase _getOrderStatsUsecase;
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final ExchangeRateRepository _exchangeRateRepository;

  Future<void> loadStatistics() async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // Fetch user currency preference
      String userCurrency = 'CAD';
      try {
        final userSummary = await _getExchangeUserSummaryUsecase.execute();
        userCurrency = userSummary.currency ?? 'CAD';
      } catch (_) {
        // Use default if user summary fetch fails
      }

      var stats = await _getOrderStatsUsecase.execute();

      // Convert CAD values to user's selected currency if different
      if (userCurrency != 'CAD') {
        try {
          stats = await _convertStatsToUserCurrency(stats, userCurrency);
        } catch (e) {
          log.warning('Currency conversion failed, using CAD values: $e');
          // Fall back to CAD if conversion fails
          userCurrency = 'CAD';
        }
      }

      emit(
        state.copyWith(
          isLoading: false,
          stats: stats,
          userCurrency: userCurrency,
        ),
      );
    } catch (e) {
      log.severe('Failed to load statistics: $e');
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Failed to load statistics',
        ),
      );
    }
  }

  /// Convert all CAD fiat values in the stats to the target currency
  Future<OrderStatsResponse> _convertStatsToUserCurrency(
    OrderStatsResponse stats,
    String targetCurrency,
  ) async {
    final orderStats = stats.orderStats;

    // Convert fiat amounts (average prices)
    final convertedAvgBuyPrice = await _convertAmountList(
      orderStats.averageBitcoinBuyPrice,
      targetCurrency,
    );
    final convertedAvgSellPrice = await _convertAmountList(
      orderStats.averageBitcoinSellPrice,
      targetCurrency,
    );

    // Convert fiat portions of volumes (keep BTC as-is)
    final convertedBuyVolume = await _convertAmountList(
      orderStats.bitcoinBuyVolume,
      targetCurrency,
    );
    final convertedSellVolume = await _convertAmountList(
      orderStats.bitcoinSellVolume,
      targetCurrency,
    );
    final convertedTotalVolume = await _convertAmountList(
      orderStats.totalBitcoinTradingVolume,
      targetCurrency,
    );

    // Convert biller stats if present
    final billerStats = stats.billerStats;
    final convertedBillerStats = billerStats.hasStats
        ? await _convertBillerStats(billerStats, targetCurrency)
        : billerStats;

    return OrderStatsResponse(
      orderStats: OrderStats(
        bitcoinBuyVolume: convertedBuyVolume,
        bitcoinBuyTradeCount: orderStats.bitcoinBuyTradeCount, // Keep as-is
        averageBitcoinBuyPrice: convertedAvgBuyPrice,
        bitcoinSellVolume: convertedSellVolume,
        bitcoinSellTradeCount: orderStats.bitcoinSellTradeCount, // Keep as-is
        averageBitcoinSellPrice: convertedAvgSellPrice,
        totalBitcoinTradingVolume: convertedTotalVolume,
        buySellRatio: orderStats.buySellRatio, // Keep as-is
      ),
      billerStats: convertedBillerStats,
      asOf: stats.asOf,
    );
  }

  /// Convert a list of AmountByCurrencyCode from CAD to target currency
  /// Keeps BTC amounts unchanged
  Future<List<AmountByCurrencyCode>> _convertAmountList(
    List<AmountByCurrencyCode> amounts,
    String targetCurrency,
  ) async {
    final result = <AmountByCurrencyCode>[];

    for (final amount in amounts) {
      // Keep BTC amounts as-is
      if (amount.currency == 'BTC') {
        result.add(amount);
        continue;
      }

      // Convert CAD to target currency
      if (amount.currency == 'CAD') {
        final convertedValue = await _exchangeRateRepository.convertFiatToFiat(
          amount: amount.value,
          fromCurrency: 'CAD',
          toCurrency: targetCurrency,
        );
        result.add(AmountByCurrencyCode(
          currency: targetCurrency,
          value: convertedValue,
        ));
      } else {
        // Keep other currencies as-is (shouldn't happen, but safe fallback)
        result.add(amount);
      }
    }

    return result;
  }

  /// Convert biller stats amounts from CAD to target currency
  Future<BillerStats> _convertBillerStats(
    BillerStats billerStats,
    String targetCurrency,
  ) async {
    // If already in target currency, no conversion needed
    if (billerStats.currency == targetCurrency) {
      return billerStats;
    }

    final convertedStats = <BillerStat>[];
    for (final stat in billerStats.stats) {
      final convertedAmount = await _exchangeRateRepository.convertFiatToFiat(
        amount: stat.totalAmount,
        fromCurrency: billerStats.currency.isNotEmpty
            ? billerStats.currency
            : 'CAD',
        toCurrency: targetCurrency,
      );
      convertedStats.add(BillerStat(
        billerName: stat.billerName,
        billerCode: stat.billerCode,
        totalAmount: convertedAmount,
        tradeCount: stat.tradeCount,
      ));
    }

    return BillerStats(
      currency: targetCurrency,
      stats: convertedStats,
    );
  }

  void clearError() {
    emit(state.copyWith(error: null));
  }
}

