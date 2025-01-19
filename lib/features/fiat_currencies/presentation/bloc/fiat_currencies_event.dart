part of 'fiat_currencies_bloc.dart';

sealed class FiatCurrenciesEvent {
  const FiatCurrenciesEvent();
}

class FiatCurrenciesStarted extends FiatCurrenciesEvent {
  // A currency to use for the bitcoin price different than the one saved in the settings
  final String? bitcoinPriceCurrency;

  // Pass a currency if you want to use another currency than the one saved in the settings
  const FiatCurrenciesStarted({this.bitcoinPriceCurrency});
}

class FiatCurrenciesBitcoinPriceFetched extends FiatCurrenciesEvent {
  const FiatCurrenciesBitcoinPriceFetched();
}

class FiatCurrenciesBitcoinPriceCurrencyChanged extends FiatCurrenciesEvent {
  final String currencyCode;
  final bool save; // Save as the selected currency in the settings

  const FiatCurrenciesBitcoinPriceCurrencyChanged({
    required this.currencyCode,
    this.save = true,
  });
}
