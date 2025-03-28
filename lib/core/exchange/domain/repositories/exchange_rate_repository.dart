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
}
