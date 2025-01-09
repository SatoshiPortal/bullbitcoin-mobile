part of 'currencies_bloc.dart';

@freezed
sealed class CurrenciesState with _$CurrenciesState {
  const factory CurrenciesState.initial() = Initial;
  const factory CurrenciesState.loadInProgress() = LoadInProgress;
  const factory CurrenciesState.success({
    required List<FiatCurrencyModel> availableCurrencies,
    required String bitcoinPriceCurrencyCode,
    required Decimal bitcoinPrice,
  }) = Success;
  const factory CurrenciesState.failure(Object? e) = Failure;
}

class CurrenciesInitial extends CurrenciesState implements Initial {
  const CurrenciesInitial() : super.initial();
}

class CurrenciesLoadInProgress extends CurrenciesState
    implements LoadInProgress {
  const CurrenciesLoadInProgress() : super.loadInProgress();
}

class CurrenciesSuccess extends CurrenciesState implements Success {
  const CurrenciesSuccess({
    required this.availableCurrencies,
    required this.bitcoinPriceCurrencyCode,
    required this.bitcoinPrice,
  }) : super.success(
          availableCurrencies: availableCurrencies,
          bitcoinPriceCurrencyCode: bitcoinPriceCurrencyCode,
          bitcoinPrice: bitcoinPrice,
        );

  @override
  final List<FiatCurrencyModel> availableCurrencies;
  @override
  final String bitcoinPriceCurrencyCode;
  @override
  final Decimal bitcoinPrice;
}

class CurrenciesFailure extends CurrenciesState implements Failure {
  const CurrenciesFailure(Object? e) : super.failure(e);
}
