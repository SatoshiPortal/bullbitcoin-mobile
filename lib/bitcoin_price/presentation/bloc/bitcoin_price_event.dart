part of 'bitcoin_price_bloc.dart';

sealed class BitcoinPriceEvent {
  const BitcoinPriceEvent();
}

class BitcoinPriceStarted extends BitcoinPriceEvent {
  // A currency to use for the bitcoin price different than the one saved in the settings
  final String? currency;

  // Pass a currency if you want to use another currency than the one saved in the settings
  const BitcoinPriceStarted({this.currency});
}

class BitcoinPriceFetched extends BitcoinPriceEvent {
  const BitcoinPriceFetched();
}

class BitcoinPriceCurrencyChanged extends BitcoinPriceEvent {
  final String currencyCode;

  const BitcoinPriceCurrencyChanged({
    required this.currencyCode,
  });
}
