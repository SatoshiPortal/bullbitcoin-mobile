part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeState with _$FundExchangeState {
  const factory FundExchangeState({
    @Default(false) bool isStarted,
    UserSummary? userSummary,
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
    @Default(FundingJurisdiction.canada) FundingJurisdiction jurisdiction,
    FundingDetails? fundingDetails,
    GetExchangeFundingDetailsException? getExchangeFundingDetailsException,
    @Default(false) bool isSubmittingScamWarningConsent,
    String? scamWarningConsentError,
  }) = _FundExchangeState;
  const FundExchangeState._();

  bool get failedToLoadFundingDetails =>
      getExchangeFundingDetailsException != null;
}
