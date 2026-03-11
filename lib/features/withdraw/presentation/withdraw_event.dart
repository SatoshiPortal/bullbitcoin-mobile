part of 'withdraw_bloc.dart';

@freezed
sealed class WithdrawEvent with _$WithdrawEvent {
  const factory WithdrawEvent.started() = WithdrawStarted;
  const factory WithdrawEvent.recipientSelected(
    RecipientViewModel recipient, {
    required bool isNew,
  }) = WithdrawRecipientSelected;
  const factory WithdrawEvent.amountInputContinuePressed({
    required String amountInput,
    required FiatCurrency fiatCurrency,
  }) = WithdrawAmountInputContinuePressed;
  /*const factory WithdrawEvent.descriptionInputContinuePressed(
    String description,
  ) = WithdrawDescriptionInputContinuePressed;*/
  const factory WithdrawEvent.confirmed() = WithdrawConfirmed;
}
