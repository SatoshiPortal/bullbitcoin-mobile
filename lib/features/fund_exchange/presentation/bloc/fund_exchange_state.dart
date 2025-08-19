part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeState with _$FundExchangeState {
  const factory FundExchangeState({
    @Default(FundingJurisdiction.canada) FundingJurisdiction jurisdiction,
    @Default(false) bool hasConfirmedNoCoercion,
    UserSummary? userSummary,
    FundingDetails? fundingDetails,
    GetExchangeFundingDetailsException? getExchangeFundingDetailsException,
  }) = _FundExchangeState;
  const FundExchangeState._();

  bool get failedToLoadFundingDetails =>
      getExchangeFundingDetailsException != null;
}
