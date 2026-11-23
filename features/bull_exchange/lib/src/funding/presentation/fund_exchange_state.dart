part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeState with _$FundExchangeState {
  const factory FundExchangeState({
    @Default(false) bool isStarted,
    UserSummary? userSummary,
    @Default(false) bool isConfidentialSepaAvailable,
    @Default(false) bool isLoadingConfidentialSepaAvailability,
    FundExchangeFailure? confidentialSepaAvailabilityFailure,
    @Default(false) bool isLoadingFundingInstitutions,
    List<FundingInstitution>? fundingInstitutions,
    FundExchangeFailure? listFundingInstitutionsFailure,
    @Default(false) bool isLoadingFundingDetails,
    FundingDetails? fundingDetails,
    FundExchangeFailure? getFundingDetailsFailure,
    @Default(false) bool isSubmittingScamWarningConsent,
    FundExchangeFailure? submitScamWarningConsentFailure,
    PendingConsentAction? pendingConsentAction,
    @Default(false) bool isOpeningPaymentLink,
    FundExchangeFailure? openPaymentLinkFailure,
  }) = _FundExchangeState;
  const FundExchangeState._();

  bool get failedToLoadFundingDetails => getFundingDetailsFailure != null;

  bool get isFundingRestricted => userSummary?.isFundingRestricted ?? false;

  /// The jurisdiction of the account's currency. USD is Costa Rica, where its
  /// funding rails are.
  Jurisdiction get initialFundingJurisdiction => ExchangeCatalog.jurisdictionOf(
    ExchangeCatalog.legacyCurrencyOrFallback(userSummary?.currency),
  );

  bool get shouldShowScamWarningConsent =>
      userSummary != null &&
      !userSummary!.hasConsentedScamWarning &&
      !isSubmittingScamWarningConsent;
}
