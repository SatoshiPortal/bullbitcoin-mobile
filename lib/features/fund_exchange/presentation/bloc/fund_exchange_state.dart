part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeState with _$FundExchangeState {
  const factory FundExchangeState({
    @Default(false) bool isStarted,
    UserSummary? userSummary,
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
    @Default(FundingJurisdiction.canada) FundingJurisdiction jurisdiction,
    @Default(false) bool hasConfirmedNoCoercion,
    FundingDetails? fundingDetails,
    GetExchangeFundingDetailsException? getExchangeFundingDetailsException,
  }) = _FundExchangeState;
  const FundExchangeState._();

  bool get isFullyVerifiedKycLevel =>
      userSummary?.isFullyVerifiedKycLevel == true;

  bool get failedToLoadFundingDetails =>
      getExchangeFundingDetailsException != null;
}
