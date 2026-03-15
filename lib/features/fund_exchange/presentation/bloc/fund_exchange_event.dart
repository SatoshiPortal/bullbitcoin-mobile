part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeEvent with _$FundExchangeEvent {
  const factory FundExchangeEvent.started() = FundExchangeStarted;
  const factory FundExchangeEvent.jurisdictionChanged(
    FundingJurisdiction jurisdiction,
  ) = FundExchangeJurisdictionChanged;
  const factory FundExchangeEvent.fundingDetailsRequested({
    required FundingMethod fundingMethod,
  }) = FundExchangeFundingDetailsRequested;
  const factory FundExchangeEvent.scamWarningConsentSubmitted() =
      FundExchangeScamWarningConsentSubmitted;
  const FundExchangeEvent._();
}
