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
    @Default(false) bool isCreatingWithdrawOrder,
    WithdrawError? newRecipientError,
    WithdrawError? selectedRecipientError,
  }) = WithdrawRecipientInputState;
  const factory WithdrawState.paymentDetailsInput({
    required UserSummary userSummary,
    required FiatAmount amount,
    required FiatCurrency currency,
    required RecipientSelection recipient,
    @Default(false) bool isCreatingWithdrawOrder,
    WithdrawError? error,
  }) = WithdrawPaymentDetailsInputState;
  /*onst factory WithdrawState.descriptionInput({
    required UserSummary userSummary,
    required RecipientSelection recipient,
    required FiatAmount fiatOrderAmount,
    required FiatCurrency fiatCurrency,
    @Default(false) bool isCreatingWithdrawOrder,
    WithdrawError? error,
  }) = WithdrawDescriptionInputState;*/
  const factory WithdrawState.confirmation({
    required UserSummary userSummary,
    required FiatAmount amount,
    required FiatCurrency currency,
    required RecipientSelection recipient,
    //required String description,
    required WithdrawOrder order,
    InteracSecurityDetails? interacSecurityDetails,
    @Default(false) bool saveSecurityDetailsAsDefault,
    @Default(false) bool isConfirmingWithdrawal,
    WithdrawError? error,
  }) = WithdrawConfirmationState;
  const factory WithdrawState.success({required WithdrawOrder order}) =
      WithdrawSuccessState;
  const WithdrawState._();

  FiatCurrency get currency {
    return when(
      initial: (_) => FiatCurrency.cad,
      amountInput: (userSummary) => userSummary.currency != null
          ? FiatCurrency.fromCode(userSummary.currency!)
          : FiatCurrency.cad,
      recipientInput: (_, _, currency, _, _, _) => currency,
      paymentDetailsInput: (_, _, currency, _, _, _) => currency,
      confirmation: (_, _, currency, _, _, _, _, _, _) => currency,
      success: (order) => FiatCurrency.fromCode(order.payoutCurrency),
    );
  }

  WithdrawAmountInputState? get cleanAmountInputState {
    return whenOrNull(
      amountInput: (userSummary) =>
          WithdrawAmountInputState(userSummary: userSummary),
      recipientInput:
          (
            userSummary,
            amount,
            currency,
            isCreatingWithdrawOrder,
            newRecipientError,
            selectedRecipientError,
          ) => WithdrawAmountInputState(userSummary: userSummary),
      paymentDetailsInput:
          (userSummary, amount, currency, recipient, isCreating, error) =>
              WithdrawAmountInputState(userSummary: userSummary),
      confirmation:
          (
            userSummary,
            amount,
            currency,
            recipient,
            order,
            interacSecurityDetails,
            saveSecurityDetailsAsDefault,
            isConfirmingWithdrawal,
            error,
          ) => WithdrawAmountInputState(userSummary: userSummary),
    );
  }

  WithdrawRecipientInputState? get cleanRecipientInputState {
    return whenOrNull(
      recipientInput:
          (
            userSummary,
            amount,
            currency,
            isCreatingWithdrawOrder,
            newRecipientError,
            selectedRecipientError,
          ) => WithdrawRecipientInputState(
            userSummary: userSummary,
            amount: amount,
            currency: currency,
            isCreatingWithdrawOrder: false,
            newRecipientError: null,
            selectedRecipientError: null,
          ),
      paymentDetailsInput:
          (userSummary, amount, currency, recipient, isCreating, error) =>
              WithdrawRecipientInputState(
                userSummary: userSummary,
                amount: amount,
                currency: currency,
              ),
      confirmation:
          (
            userSummary,
            amount,
            currency,
            recipient,
            order,
            interacSecurityDetails,
            saveSecurityDetailsAsDefault,
            isConfirmingWithdrawal,
            error,
          ) => WithdrawRecipientInputState(
            userSummary: userSummary,
            amount: amount,
            currency: currency,
          ),
    );
  }

  WithdrawConfirmationState? get cleanConfirmationState {
    return whenOrNull(
      confirmation:
          (
            userSummary,
            amount,
            currency,
            recipient,
            order,
            interacSecurityDetails,
            saveSecurityDetailsAsDefault,
            isConfirmingWithdrawal,
            error,
          ) => WithdrawConfirmationState(
            userSummary: userSummary,
            amount: amount,
            currency: currency,
            recipient: recipient,
            order: order,
            interacSecurityDetails: interacSecurityDetails,
            saveSecurityDetailsAsDefault: saveSecurityDetailsAsDefault,
            error: null,
          ),
    );
  }

  WithdrawPaymentDetailsInputState? get cleanPaymentDetailsInputState {
    return whenOrNull(
      paymentDetailsInput:
          (userSummary, amount, currency, recipient, isCreating, error) =>
              WithdrawPaymentDetailsInputState(
                userSummary: userSummary,
                amount: amount,
                currency: currency,
                recipient: recipient,
              ),
      confirmation:
          (
            userSummary,
            amount,
            currency,
            recipient,
            order,
            interacSecurityDetails,
            saveSecurityDetailsAsDefault,
            isConfirmingWithdrawal,
            error,
          ) => WithdrawPaymentDetailsInputState(
            userSummary: userSummary,
            amount: amount,
            currency: currency,
            recipient: recipient,
          ),
    );
  }
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
    required RecipientSelection recipient,
    required WithdrawOrder order,
  }) {
    return WithdrawConfirmationState(
      userSummary: userSummary,
      amount: amount,
      currency: currency,
      recipient: recipient,
      order: order,
    );
  }

  WithdrawPaymentDetailsInputState toPaymentDetailsInputState({
    required RecipientSelection recipient,
  }) {
    return WithdrawPaymentDetailsInputState(
      userSummary: userSummary,
      amount: amount,
      currency: currency,
      recipient: recipient,
    );
  }
}

extension WithdrawPaymentDetailsInputStateX
    on WithdrawPaymentDetailsInputState {
  WithdrawConfirmationState toConfirmationState({
    required WithdrawOrder order,
    required InteracSecurityDetails interacSecurityDetails,
    required bool saveSecurityDetailsAsDefault,
  }) {
    return WithdrawConfirmationState(
      userSummary: userSummary,
      amount: amount,
      currency: currency,
      recipient: recipient,
      order: order,
      interacSecurityDetails: interacSecurityDetails,
      saveSecurityDetailsAsDefault: saveSecurityDetailsAsDefault,
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
