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
    final p = bitcoinPrice! * (satAmount / 100000000);
    if (currency == null) return null;
    return '${_fiatFormatting(p.toStringAsFixed(2))} ${currency!}';
  }

  String? displayBTCAmount(int satsAmount, BitcoinUnit unit) {
    if (unit == BitcoinUnit.btc) {
      final btcAmount = (satsAmount / 100000000).toStringAsFixed(8);
      return '${_removeTrailingZeros(btcAmount)} BTC';
    } else {
      return '$satsAmount sats';
    }
  }

  String _fiatFormatting(String fiatAmount) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    return _removeTrailingZeros(
      currency.format(
        double.parse(fiatAmount),
      ),
    );
  }

  String _removeTrailingZeros(String value) {
    if (value.contains('.')) {
      return value
          .replaceAll(RegExp(r'0*$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    return value;
  }
}
