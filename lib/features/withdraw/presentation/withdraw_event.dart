part of 'withdraw_bloc.dart';

@Freezed(toStringOverride: false)
sealed class WithdrawEvent with _$WithdrawEvent {
  const factory WithdrawEvent.started() = WithdrawStarted;
  const factory WithdrawEvent.recipientSelected(
    RecipientSelection recipient, {
    required bool isNew,
  }) = WithdrawRecipientSelected;
  const factory WithdrawEvent.amountInputContinuePressed({
    required String amountInput,
    required FiatCurrency fiatCurrency,
  }) = WithdrawAmountInputContinuePressed;
  const factory WithdrawEvent.interacSecurityDetailsSubmitted({
    required String securityQuestion,
    required String securityAnswer,
    required bool saveAsDefault,
  }) = WithdrawInteracSecurityDetailsSubmitted;
  const factory WithdrawEvent.confirmed() = WithdrawConfirmed;
  const factory WithdrawEvent.virtualPayeeActivated() =
      WithdrawVirtualPayeeActivated;
  const factory WithdrawEvent.regularSepaChosen() = WithdrawRegularSepaChosen;
  const factory WithdrawEvent.virtualPayeeActivationDismissed() =
      WithdrawVirtualPayeeActivationDismissed;
}
