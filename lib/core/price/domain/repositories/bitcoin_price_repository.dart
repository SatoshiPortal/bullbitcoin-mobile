abstract interface class BitcoinPriceRepository {
  Future<List<String>> get availableCurrencies;

  /// When the price served for [currency] was fetched from the pricer, or null
  /// when none is held. A read may be answered from a recent fetch without a
  /// request, so this is when the pricer last answered for it.
  DateTime? priceFetchedAt(String currency);

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
