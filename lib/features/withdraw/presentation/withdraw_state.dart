part of 'withdraw_bloc.dart';

@freezed
sealed class WithdrawState with _$WithdrawState {
  const factory WithdrawState.initial({
    GetExchangeUserSummaryException? getUserSummaryException,
  }) = WithdrawInitialState;
  const factory WithdrawState.amountInput({required UserSummary userSummary}) =
      WithdrawAmountInputState;
  const factory WithdrawState.recipientInput({
    required UserSummary userSummary,
    required FiatAmount amount,
    required FiatCurrency currency,
    String? paymentDescription,
    @Default(false) bool isCreatingWithdrawOrder,
    WithdrawFailure? newRecipientError,
    WithdrawFailure? selectedRecipientError,
    RecipientViewModel? selectedRecipient,
  }) = WithdrawRecipientInputState;
  /*onst factory WithdrawState.descriptionInput({
    required UserSummary userSummary,
    required RecipientViewModel recipient,
    required FiatAmount fiatOrderAmount,
    required FiatCurrency fiatCurrency,
    @Default(false) bool isCreatingWithdrawOrder,
    WithdrawFailure? error,
  }) = WithdrawDescriptionInputState;*/
  const factory WithdrawState.confirmation({
    required UserSummary userSummary,
    required FiatAmount amount,
    required FiatCurrency currency,
    required RecipientViewModel recipient,
    String? paymentDescription,
    required WithdrawOrder order,
    @Default(false) bool isConfirmingWithdrawal,
    WithdrawFailure? error,
  }) = WithdrawConfirmationState;
  const factory WithdrawState.success({required WithdrawOrder order}) =
      WithdrawSuccessState;
  const WithdrawState._();

  FiatCurrency get currency => switch (this) {
    WithdrawInitialState() => FiatCurrency.cad,
    WithdrawAmountInputState(:final userSummary) =>
      userSummary.currency != null
          ? FiatCurrency.fromCode(userSummary.currency!)
          : FiatCurrency.cad,
    WithdrawRecipientInputState(:final currency) => currency,
    WithdrawConfirmationState(:final currency) => currency,
    WithdrawSuccessState(:final order) => FiatCurrency.fromCode(
      order.payoutCurrency,
    ),
  };

  WithdrawAmountInputState? get cleanAmountInputState => switch (this) {
    WithdrawAmountInputState(:final userSummary) => WithdrawAmountInputState(
      userSummary: userSummary,
    ),
    WithdrawRecipientInputState(:final userSummary) => WithdrawAmountInputState(
      userSummary: userSummary,
    ),
    WithdrawConfirmationState(:final userSummary) => WithdrawAmountInputState(
      userSummary: userSummary,
    ),
    _ => null,
  };

  WithdrawRecipientInputState? get cleanRecipientInputState => switch (this) {
    WithdrawRecipientInputState(
      :final userSummary,
      :final amount,
      :final currency,
      :final paymentDescription,
    ) =>
      WithdrawRecipientInputState(
        userSummary: userSummary,
        amount: amount,
        currency: currency,
        paymentDescription: paymentDescription,
      ),
    WithdrawConfirmationState(
      :final userSummary,
      :final amount,
      :final currency,
      :final paymentDescription,
    ) =>
      WithdrawRecipientInputState(
        userSummary: userSummary,
        amount: amount,
        currency: currency,
        paymentDescription: paymentDescription,
      ),
    _ => null,
  };

  WithdrawConfirmationState? get cleanConfirmationState => switch (this) {
    WithdrawConfirmationState(
      :final userSummary,
      :final amount,
      :final currency,
      :final recipient,
      :final paymentDescription,
      :final order,
    ) =>
      WithdrawConfirmationState(
        userSummary: userSummary,
        amount: amount,
        currency: currency,
        recipient: recipient,
        paymentDescription: paymentDescription,
        order: order,
      ),
    _ => null,
  };
}

extension WithdrawInitialStateX on WithdrawInitialState {
  WithdrawAmountInputState toAmountInputState({
    required UserSummary userSummary,
  }) {
    return WithdrawAmountInputState(userSummary: userSummary);
  }
}

extension WithdrawAmountInputStateX on WithdrawAmountInputState {
  WithdrawRecipientInputState toRecipientInputState({
    required FiatAmount amount,
    required FiatCurrency currency,
  }) {
    return WithdrawRecipientInputState(
      userSummary: userSummary,
      amount: amount,
      currency: currency,
    );
  }
}

extension WithdrawRecipientInputStateX on WithdrawRecipientInputState {
  WithdrawConfirmationState toConfirmationState({
    required RecipientViewModel recipient,
    required WithdrawOrder order,
  }) {
    return WithdrawConfirmationState(
      userSummary: userSummary,
      amount: amount,
      currency: currency,
      recipient: recipient,
      paymentDescription: paymentDescription,
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
  /*WithdrawDescriptionInputState toDescriptionInputState() {
    return WithdrawDescriptionInputState(
      userSummary: userSummary,
      recipients: recipients,
      recipient: recipient,
      fiatOrderAmount: fiatOrderAmount,
      fiatCurrency: fiatCurrency,
    );
  }*/

  WithdrawSuccessState toSuccessState({required WithdrawOrder order}) {
    return WithdrawSuccessState(order: order);
  }
}
