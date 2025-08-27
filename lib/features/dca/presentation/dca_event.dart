part of 'dca_bloc.dart';

@freezed
sealed class DcaEvent with _$DcaEvent {
  const factory DcaEvent.started() = DcaStarted;
  const factory DcaEvent.amountInputContinuePressed({
    required String amountInput,
    required FiatCurrency currency,
    //required DcaFrequency frequency,
  }) = DcaAmountInputContinuePressed;
  const factory DcaEvent.walletSelected({Wallet? wallet, String? destination}) =
      DcaWalletSelected;
  const factory DcaEvent.confirmed() = DcaConfirmed;
}
