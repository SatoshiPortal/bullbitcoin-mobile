part of 'currencies_bloc.dart';

sealed class CurrenciesEvent {
  const CurrenciesEvent();
}

class CurrenciesFetched extends CurrenciesEvent {
  const CurrenciesFetched();
}

class CurrenciesBitcoinPriceCurrencyChanged extends CurrenciesEvent {
  const CurrenciesBitcoinPriceCurrencyChanged({
    required this.currencyCode,
  });

  final String currencyCode;
}
