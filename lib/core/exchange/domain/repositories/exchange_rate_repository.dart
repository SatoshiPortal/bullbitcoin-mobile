import 'package:bb_mobile/core/exchange/domain/entity/composite_rate_history.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate_history.dart';

abstract class ExchangeRateRepository {
  Future<List<String>> get availableCurrencies;
  Future<double> getCurrencyValue({
    required BigInt amountSat,
    required String currency,
  });
  Future<BigInt> getSatsValue({
    required double amountFiat,
    required String currency,
  });
  Future<RateHistory> getIndexRateHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  });
  Future<Map<RateTimelineInterval, RateHistory>> getAllIntervalsRateHistory({
    required String fromCurrency,
    required String toCurrency,
    DateTime? fromDate,
    DateTime? toDate,
  });
  Future<void> refreshAllRateHistory({
    required String fromCurrency,
    required String toCurrency,
  });
  Future<void> refreshRateHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<CompositeRateHistory> getCompositeRateHistory({
    required String fromCurrency,
    required String toCurrency,
  });
}
