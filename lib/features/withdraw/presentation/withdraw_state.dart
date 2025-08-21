part of 'withdraw_bloc.dart';

@freezed
sealed class WithdrawState with _$WithdrawState {
  const factory WithdrawState.initial({
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
    ListRecipientsException? listRecipientsException,
  }) = WithdrawInitialState;
  const factory WithdrawState.amountInput({
    required UserSummary userSummary,
    required List<Recipient> recipients,
  }) = WithdrawAmountInputState;
  const factory WithdrawState.recipientInput({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required FiatAmount amount,
    required FiatCurrency currency,
    @Default(false) bool isCreatingWithdrawOrder,
    WithdrawError? error,
    NewRecipient? newRecipient,
  }) = WithdrawRecipientInputState;
  /*onst factory WithdrawState.descriptionInput({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required Recipient recipient,
    required FiatAmount fiatOrderAmount,
    required FiatCurrency fiatCurrency,
    @Default(false) bool isCreatingWithdrawOrder,
    WithdrawError? error,
  }) = WithdrawDescriptionInputState;*/
  const factory WithdrawState.confirmation({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required FiatAmount amount,
    required FiatCurrency currency,
    required Recipient recipient,
    //required String description,
    required WithdrawOrder order,
    @Default(false) bool isConfirmingWithdrawal,
    WithdrawError? error,
  }) = WithdrawConfirmationState;
  const factory WithdrawState.inProgress({required WithdrawOrder order}) =
      WithdrawInProgressState;
  const factory WithdrawState.success({required WithdrawOrder order}) =
      WithdrawSuccessState;
  const WithdrawState._();
}

extension WithdrawInitialStateX on WithdrawInitialState {
  WithdrawAmountInputState toAmountInputState({
    required UserSummary userSummary,
    required List<Recipient> recipients,
  }) {
    return WithdrawAmountInputState(
      userSummary: userSummary,
      recipients: recipients,
    );
  }
}

extension WithdrawAmountInputStateX on WithdrawAmountInputState {
  WithdrawRecipientInputState toRecipientInputState({
    required FiatAmount amount,
    required FiatCurrency currency,
  }) {
    return WithdrawRecipientInputState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
    );
  }
}

extension WithdrawRecipientInputStateX on WithdrawRecipientInputState {
  WithdrawAmountInputState toAmountInputState() {
    return WithdrawAmountInputState(
      userSummary: userSummary,
      recipients: recipients,
    );
  }

  WithdrawConfirmationState toConfirmationState({
    required Recipient recipient,
    required WithdrawOrder order,
  }) {
    return WithdrawConfirmationState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
      recipient: recipient,
      order: order,
    );
  }
}

/*extension WithdrawDescriptionInputStateX on WithdrawDescriptionInputState {
  WithdrawAmountInputState toAmountInputState() {
    return WithdrawAmountInputState(
      userSummary: userSummary,
      recipients: recipients,
      recipient: recipient,
    );
  }

  WithdrawConfirmationState toConfirmationState({
    required WithdrawOrder order,
  }) {
    return WithdrawConfirmationState(
      userSummary: userSummary,
      recipients: recipients,
      recipient: recipient,
      fiatOrderAmount: fiatOrderAmount,
      fiatCurrency: fiatCurrency,
      order: order,
    );
  }
}*/

extension WithdrawConfirmationStateX on WithdrawConfirmationState {
  WithdrawRecipientInputState toRecipientInputState() {
    return WithdrawRecipientInputState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
    );
  }
  /*WithdrawDescriptionInputState toDescriptionInputState() {
    return WithdrawDescriptionInputState(
      userSummary: userSummary,
      recipients: recipients,
      recipient: recipient,
      fiatOrderAmount: fiatOrderAmount,
      fiatCurrency: fiatCurrency,
    );
  }*/

  WithdrawInProgressState toInProgressState({required WithdrawOrder order}) {
    return WithdrawInProgressState(order: order);
  }
}

extension WithdrawInProgressStateX on WithdrawInProgressState {
  WithdrawSuccessState toSuccessState() {
    return WithdrawSuccessState(order: order);
  }
}
