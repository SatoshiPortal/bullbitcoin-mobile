part of 'fiat_currencies_bloc.dart';

@freezed
sealed class FiatCurrenciesState with _$FiatCurrenciesState {
  const factory FiatCurrenciesState.initial() = FiatCurrenciesInitial;
  const factory FiatCurrenciesState.loadInProgress() =
      FiatCurrenciesLoadInProgress;
  const factory FiatCurrenciesState.success({
    required List<String> availableCurrencies,
    required String bitcoinPriceCurrency,
    required Decimal bitcoinPrice,
  }) = FiatCurrenciesSuccess;
  const factory FiatCurrenciesState.failure(Object? e) = FiatCurrenciesFailure;
}
