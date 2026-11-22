part of 'bitcoin_price_bloc.dart';

@freezed
sealed class BitcoinPriceState with _$BitcoinPriceState {
  const factory BitcoinPriceState({
    AmountDisplayPreferences? amountDisplay,
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
  bool get hasValidFiatRate => switch (bitcoinPrice) {
    final price? => currency != null && price > 0,
    null => false,
  };

  String? calculateFiatPrice(int satAmount) {
    final rate = bitcoinPrice;
    final code = currency;
    if (rate == null || !(rate > 0) || code == null) return null;
    final fiat = rate * ConvertAmount.satsToBtc(satAmount);
    return '${_fiatFormatting(fiat.toStringAsFixed(2))} $code';
  }

  String? displayBTCAmount(int satsAmount, BitcoinUnit unit) {
    if (unit == BitcoinUnit.btc) {
      final btcAmount = ConvertAmount.satsToBtc(satsAmount).toStringAsFixed(8);
      return '${_removeTrailingBTCZeros(btcAmount)} BTC';
    } else {
      return '${_displaySatsAmount(satsAmount)} sats';
    }
  }

  String _displaySatsAmount(int satsAmount) {
    final currency = NumberFormat('#,##0', 'en_US');
    return currency.format(satsAmount);
  }

  String _fiatFormatting(String fiatAmount) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    return _removeTrailingFiatZeros(currency.format(double.parse(fiatAmount)));
  }

  String _removeTrailingFiatZeros(String value) {
    if (value.endsWith('.00')) {
      return value.replaceAll('.00', '');
    }
    return value;
  }

  String _removeTrailingBTCZeros(String value) {
    if (value.endsWith('.00')) {
      return value.replaceAll('.00', '');
    }
    if (value.contains('.')) {
      return value
          .replaceAll(RegExp(r'0*$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    return value;
  }
}
