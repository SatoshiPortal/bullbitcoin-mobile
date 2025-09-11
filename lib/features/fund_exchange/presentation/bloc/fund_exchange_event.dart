part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeEvent with _$FundExchangeEvent {
  const factory FundExchangeEvent.started() = FundExchangeStarted;
  const factory FundExchangeEvent.jurisdictionChanged(
    FundingJurisdiction jurisdiction,
  ) = FundExchangeJurisdictionChanged;
  const factory FundExchangeEvent.noCoercionConfirmed(bool confirmed) =
      FundExchangeNoCoercionConfirmed;
  const factory FundExchangeEvent.fundingDetailsRequested({
    required FundingMethod fundingMethod,
  }) = FundExchangeFundingDetailsRequested;
  const FundExchangeEvent._();
}
