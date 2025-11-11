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
    required String interval,
    DateTime? fromDate,
    DateTime? toDate,
  });
  Future<Map<String, RateHistory>> getAllIntervalsRateHistory({
    required String fromCurrency,
    required String toCurrency,
    DateTime? fromDate,
    DateTime? toDate,
  });
}
