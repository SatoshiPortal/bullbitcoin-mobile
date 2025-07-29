part of 'sell_bloc.dart';

@freezed
sealed class SellEvent with _$SellEvent {
  const factory SellEvent.started() = SellStarted;
  const factory SellEvent.confirmAmount({
    required String amountInput,
    required bool isFiatCurrencyInput,
    required FiatCurrency fiatCurrency,
  }) = SellAmountConfirmed;
}
