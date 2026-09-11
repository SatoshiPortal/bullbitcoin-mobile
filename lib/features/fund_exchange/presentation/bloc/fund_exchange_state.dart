part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeState with _$FundExchangeState {
  const factory FundExchangeState({
    @Default(false) bool isStarted,
    UserSummary? userSummary,
    @Default(false) bool isLoadingFundingInstitutions,
    List<FundingInstitution>? fundingInstitutions,
    FundExchangeFailure? listFundingInstitutionsFailure,
    @Default(false) bool isLoadingFundingDetails,
    FundingDetails? fundingDetails,
    FundExchangeFailure? getFundingDetailsFailure,
    @Default(false) bool isSubmittingScamWarningConsent,
    FundExchangeFailure? submitScamWarningConsentFailure,
    PendingConsentAction? pendingConsentAction,
  }) = _FundExchangeState;
  const FundExchangeState._();

  bool get failedToLoadFundingDetails => getFundingDetailsFailure != null;

  bool get isFundingRestricted => userSummary?.isFundingRestricted ?? false;

  FundingJurisdiction get initialFundingJurisdiction {
    // Map preffered currency to jurisdiction
    final currency = userSummary?.currency;
    switch (currency) {
      case 'CAD':
        return FundingJurisdiction.canada;
      case 'EUR':
        return FundingJurisdiction.europe;
      case 'MXN':
        return FundingJurisdiction.mexico;
      case 'CRC':
        return FundingJurisdiction.costaRica;
      case 'ARS':
        return FundingJurisdiction.argentina;
      case 'COP':
        return FundingJurisdiction.colombia;
      //case 'USD':
      //  return FundingJurisdiction.unitedStates;
      default:
        return FundingJurisdiction.canada;
    }
  }

  bool get shouldShowScamWarningConsent =>
      userSummary != null &&
      !userSummary!.hasConsentedScamWarning &&
      !isSubmittingScamWarningConsent;
}
