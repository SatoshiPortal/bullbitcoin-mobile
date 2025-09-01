part of 'dca_bloc.dart';

@freezed
sealed class DcaEvent with _$DcaEvent {
  const factory DcaEvent.started() = DcaStarted;
  const factory DcaEvent.buyInputContinuePressed({
    required String amountInput,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
  }) = DcaBuyInputContinuePressed;
  const factory DcaEvent.walletSelected({
    required DcaWalletType wallet,
    String? lightningAddress,
    bool? useDefaultLightningAddress,
  }) = DcaWalletSelected;
  const factory DcaEvent.confirmed() = DcaConfirmed;
}
