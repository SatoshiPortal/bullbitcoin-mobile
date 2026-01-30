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

  /// Convert an amount from one fiat currency to another using BTC as intermediary.
  /// Returns the converted amount in the target currency.
  Future<double> convertFiatToFiat({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  });
}
