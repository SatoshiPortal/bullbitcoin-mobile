part of 'currencies_bloc.dart';

@freezed
sealed class CurrenciesEvent with _$CurrenciesEvent {
  const factory CurrenciesEvent.currencyFetched() = Fetched;
  // ignore: non_constant_identifier_names
  const factory CurrenciesEvent.bitcoinPriceCurrencyChanged({
    required String currencyCode,
  }) = BitcoinPriceCurrencyChanged;
}

class CurrenciesFetched extends CurrenciesEvent implements Fetched {
  const CurrenciesFetched() : super.currencyFetched();
}

class CurrenciesBitcoinPriceCurrencyChanged extends CurrenciesEvent
    implements BitcoinPriceCurrencyChanged {
  const CurrenciesBitcoinPriceCurrencyChanged({
    required this.currencyCode,
  }) : super.bitcoinPriceCurrencyChanged();

  @override
  final String currencyCode;
}
