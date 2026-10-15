part of 'bitcoin_price_bloc.dart';

@freezed
sealed class BitcoinPriceState with _$BitcoinPriceState {
  const factory BitcoinPriceState({
    @Default(false) bool loadingPrice,
    BitcoinPriceFailure? failure,
    @Default(false) bool startupFailed,
    //
    List<String>? availableCurrencies,
    String? currency,
    double? bitcoinPrice,
  }) = _BitcoinPriceState;
  const BitcoinPriceState._();

  /// Fiat per 1 BTC from the API; must be positive to display converted amounts.
  bool get hasValidFiatRate =>
      currency != null && bitcoinPrice != null && bitcoinPrice! > 0;

  String? calculateFiatPrice(int satAmount) {
    if (!hasValidFiatRate) return null;
    final p = bitcoinPrice! * ConvertAmount.satsToBtc(satAmount);
    if (currency == null) return null;
    // Whole amounts drop their cents: `7,123 CAD`, but `7,123.51 CAD`.
    final rounded = double.parse(p.toStringAsFixed(2));
    final decimals = rounded == rounded.truncateToDouble() ? 0 : 2;
    final amount = BullNumberFormat.decimal(
      rounded,
      minDecimals: decimals,
      maxDecimals: decimals,
    );
    return '$amount ${currency!}';
  }
}
