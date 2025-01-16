part of 'currencies_bloc.dart';

@freezed
sealed class CurrenciesState with _$CurrenciesState {
  const factory CurrenciesState.initial() = CurrenciesInitial;
  const factory CurrenciesState.loadInProgress() = CurrenciesLoadInProgress;
  const factory CurrenciesState.success({
    required List<FiatCurrencyModel> availableCurrencies,
    required String bitcoinPriceCurrencyCode,
    required Decimal bitcoinPrice,
  }) = CurrenciesSuccess;
  const factory CurrenciesState.failure(Object? e) = CurrenciesFailure;
}
