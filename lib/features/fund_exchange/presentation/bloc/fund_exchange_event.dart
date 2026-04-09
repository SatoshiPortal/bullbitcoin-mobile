part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeEvent with _$FundExchangeEvent {
  const factory FundExchangeEvent.started() = FundExchangeStarted;
  const factory FundExchangeEvent.fundingInstitutionsRequested({
    required FundingJurisdiction jurisdiction,
  }) = FundExchangeFundingInstitutionsRequested;
  const factory FundExchangeEvent.fundingDetailsRequested({
    required FundingMethod fundingMethod,
  }) = FundExchangeFundingDetailsRequested;
  const factory FundExchangeEvent.scamWarningConsentSubmitted() =
      FundExchangeScamWarningConsentSubmitted;
  const factory FundExchangeEvent.scamWarningDismissed() =
      FundExchangeScamWarningDismissed;
  const FundExchangeEvent._();
}
