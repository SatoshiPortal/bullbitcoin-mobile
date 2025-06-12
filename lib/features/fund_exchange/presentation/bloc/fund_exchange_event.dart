part of 'fund_exchange_bloc.dart';

@freezed
sealed class FundExchangeEvent with _$FundExchangeEvent {
  const factory FundExchangeEvent.started() = FundExchangeStarted;
  const factory FundExchangeEvent.countryChanged(FundingCountry country) =
      FundExchangeCountryChanged;
  const factory FundExchangeEvent.noCoercionConfirmed(bool confirmed) =
      FundExchangeNoCoercionConfirmed;
  const factory FundExchangeEvent.emailETransferRequested() =
      FundExchangeEmailETransferRequested;
  const factory FundExchangeEvent.bankTransferWireRequested() =
      FundExchangeBankTransferWireRequested;
  const factory FundExchangeEvent.canadaPostRequested() =
      FundExchangeCanadaPostRequested;
  const factory FundExchangeEvent.onlineBillPaymentRequested() =
      FundExchangeOnlineBillPaymentRequested;
  const factory FundExchangeEvent.sepaTransferRequested() =
      FundExchangeSepaTransferRequested;
  const factory FundExchangeEvent.speiTransferRequested() =
      FundExchangeSpeiTransferRequested;
  const FundExchangeEvent._();
}
