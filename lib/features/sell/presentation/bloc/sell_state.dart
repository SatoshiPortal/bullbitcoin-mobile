part of 'sell_bloc.dart';

@freezed
sealed class SellState with _$SellState {
  const factory SellState.initial({
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
  }) = SellInitialState;
  const factory SellState.amount({
    required UserSummary userSummary,
    required double userRate,
    required BitcoinUnit bitcoinUnit,
    @Default(false) bool isConfirmingAmount,
  }) = SellAmountState;
  const factory SellState.payoutMethod({
    required UserSummary userSummary,
    required double userRate,
    required BitcoinUnit bitcoinUnit,
    required OrderAmount orderAmount,
    required FiatCurrency fiatCurrency,
    @Default(false) bool isConfirmingPayoutMethod,
    SellError? error,
  }) = SellPayoutMethodState;
  const SellState._();
}

extension SellAmountStateX on SellAmountState {
  SellPayoutMethodState toPayoutMethodState({
    required OrderAmount orderAmount,
    required FiatCurrency fiatCurrency,
  }) {
    return SellPayoutMethodState(
      userSummary: userSummary,
      userRate: userRate,
      bitcoinUnit: bitcoinUnit,
      orderAmount: orderAmount,
      fiatCurrency: fiatCurrency,
    );
  }
}

extension SellPayoutMethodStateX on SellPayoutMethodState {
  SellAmountState toAmountState() {
    return SellAmountState(
      userSummary: userSummary,
      userRate: userRate,
      bitcoinUnit: bitcoinUnit,
    );
  }
}
