part of 'withdraw_bloc.dart';

@freezed
sealed class WithdrawEvent with _$WithdrawEvent {
  const factory WithdrawEvent.started() = WithdrawStarted;
  const factory WithdrawEvent.newRecipientAdded() = WithdrawNewRecipientAdded;
  const factory WithdrawEvent.createNewRecipient(NewRecipient newRecipient) =
      WithdrawCreateNewRecipient;
  const factory WithdrawEvent.recipientSelected(Recipient recipient) =
      WithdrawRecipientSelected;
  const factory WithdrawEvent.amountInputContinuePressed({
    required String amountInput,
    required FiatCurrency fiatCurrency,
  }) = WithdrawAmountInputContinuePressed;
  const factory WithdrawEvent.getCadBillers({required String searchTerm}) =
      WithdrawGetCadBillers;
  /*const factory WithdrawEvent.descriptionInputContinuePressed(
    String description,
  ) = WithdrawDescriptionInputContinuePressed;*/
  const factory WithdrawEvent.confirmed() = WithdrawConfirmed;
}
