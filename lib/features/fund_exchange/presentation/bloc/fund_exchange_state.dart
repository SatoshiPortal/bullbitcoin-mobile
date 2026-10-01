part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeState with _$FundExchangeState {
  const factory FundExchangeState({
    @Default(false) bool isStarted,
    UserSummary? userSummary,
    GetExchangeUserSummaryException? getUserSummaryException,
    @Default(false) bool isLoadingFundingInstitutions,
    List<FundingInstitution>? fundingInstitutions,
    FundExchangePresentationError? listFundingInstitutionsException,
    @Default(false) bool isLoadingFundingDetails,
    FundingDetails? fundingDetails,
    FundExchangePresentationError? getExchangeFundingDetailsException,
    @Default(false) bool isSubmittingScamWarningConsent,
    FundExchangePresentationError? submitScamWarningConsentException,
    PendingConsentAction? pendingConsentAction,
    VirtualIban? virtualIban,
  }) = _FundExchangeState;
  const FundExchangeState._();

  bool get failedToLoadFundingDetails =>
      getExchangeFundingDetailsException != null;

  bool get isFundingRestricted => userSummary?.isFundingRestricted ?? false;

  bool get canShowConfidentialSepa => !(userSummary?.isCorporate ?? true);

  String get confidentialSepaOwnerName {
    final profile = userSummary?.profile;
    if (profile == null) return '';
    return '${profile.firstName} ${profile.lastName}'.trim();
  }

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
