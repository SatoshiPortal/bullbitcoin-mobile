part of 'bitcoin_price_bloc.dart';

@freezed
sealed class BitcoinPriceState with _$BitcoinPriceState {
  const factory BitcoinPriceState({
    @Default(false) bool loadingPrice,
    Object? error,
    //
    List<String>? availableCurrencies,
    String? currency,
    Decimal? bitcoinPrice,
  }) = _BitcoinPriceState;
  const BitcoinPriceState._();

  String? calculateFiatPrice(int satAmount) {
    if (bitcoinPrice == null) return null;
    final p = bitcoinPrice!.toDouble() * (satAmount / 100000000);
    if (currency == null) return null;
    return '${_fiatFormatting(p.toStringAsFixed(2))} ${currency!}';
  }

  String? displayBTCAmount(int satsAmount, BitcoinUnit unit) {
    if (unit == BitcoinUnit.btc) {
      return '${(satsAmount / 100000000).toStringAsFixed(8)} BTC';
    } else {
      return '$satsAmount sats';
    }
  }

  String _fiatFormatting(String fiatAmount) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    return currency.format(
      double.parse(fiatAmount),
    );
  }
}
