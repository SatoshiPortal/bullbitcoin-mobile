part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeState with _$FundExchangeState {
  const factory FundExchangeState({
    UserSummary? userSummary,
    GetExchangeUserSummaryException? getUserSummaryException,
    @Default(FundingCountry.canada) FundingCountry fundingCountry,
    @Default(false) bool hasConfirmedNoCoercion,
    String? emailETransferSecretQuestion,
    String? emailETransferSecretAnswer,
    String? bankTransferWireCode,
    String? canadaPostLoadhubQRCode,
    String? onlineBillPaymentAccountNumber,
    String? sepaTransferCode,
    String? speiTransferMemo,
  }) = _FundExchangeState;
  const FundExchangeState._();

  bool get isFetchingUserSummary =>
      getUserSummaryException == null && userSummary == null;
}
