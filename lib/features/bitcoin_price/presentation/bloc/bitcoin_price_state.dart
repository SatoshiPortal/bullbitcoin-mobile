part of 'bitcoin_price_bloc.dart';

@freezed
sealed class BitcoinPriceState with _$BitcoinPriceState {
  const factory BitcoinPriceState({
    @Default(false) bool loadingPrice,
    Object? error,
    //
    List<String>? availableCurrencies,
    String? currency,
    double? bitcoinPrice,
  }) = _BitcoinPriceState;
  const BitcoinPriceState._();

  String? calculateFiatPrice(int satAmount) {
    if (bitcoinPrice == null) return null;
    final p = bitcoinPrice! * ConvertAmount.satsToBtc(satAmount);
    if (currency == null) return null;
    return '${_fiatFormatting(p.toStringAsFixed(2))} ${currency!}';
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
