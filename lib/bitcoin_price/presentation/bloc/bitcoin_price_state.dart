part of 'bitcoin_price_bloc.dart';

@freezed
sealed class BitcoinPriceState with _$BitcoinPriceState {
  const factory BitcoinPriceState.initial() = BitcoinPriceInitial;
  const factory BitcoinPriceState.loadInProgress() = BitcoinPriceLoadInProgress;
  const factory BitcoinPriceState.success({
    required List<String> availableCurrencies,
    required String currency,
    required Decimal bitcoinPrice,
  }) = BitcoinPriceSuccess;
  const factory BitcoinPriceState.failure(Object? e) = BitcoinPriceFailure;
}
