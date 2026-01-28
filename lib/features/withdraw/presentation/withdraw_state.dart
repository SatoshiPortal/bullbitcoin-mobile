part of 'withdraw_bloc.dart';

@freezed
sealed class WithdrawState with _$WithdrawState {
  const factory WithdrawState.initial({
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
  }) = WithdrawInitialState;
  const factory WithdrawState.amountInput({
    required UserSummary userSummary,
    /// Whether the user has an active Virtual IBAN (Confidential SEPA).
    @Default(false) bool hasActiveVirtualIban,
    /// Whether to use Virtual IBAN for EUR withdrawals (defaults to true when VIBAN is active).
    @Default(true) bool useVirtualIban,
  }) = WithdrawAmountInputState;
  const factory WithdrawState.recipientInput({
    required UserSummary userSummary,
    required FiatAmount amount,
    required FiatCurrency currency,
    /// Whether the user has an active Virtual IBAN (Confidential SEPA).
    @Default(false) bool hasActiveVirtualIban,
    /// Whether to use Virtual IBAN for EUR withdrawals.
    @Default(false) bool useVirtualIban,
    @Default(false) bool isCreatingWithdrawOrder,
    // From develop: separate error fields for new vs selected recipient
    WithdrawError? newRecipientError,
    WithdrawError? selectedRecipientError,
  }) = WithdrawRecipientInputState;
  /*onst factory WithdrawState.descriptionInput({
    required UserSummary userSummary,
    required RecipientViewModel recipient,
    required FiatAmount fiatOrderAmount,
    required FiatCurrency fiatCurrency,
    @Default(false) bool isCreatingWithdrawOrder,
    WithdrawError? error,
  }) = WithdrawDescriptionInputState;*/
  const factory WithdrawState.confirmation({
    required UserSummary userSummary,
    required FiatAmount amount,
    required FiatCurrency currency,
    required RecipientViewModel recipient,
    //required String description,
    required WithdrawOrder order,
    @Default(false) bool isConfirmingWithdrawal,
    WithdrawError? error,
  }) = WithdrawConfirmationState;
  const factory WithdrawState.success({required WithdrawOrder order}) =
      WithdrawSuccessState;
  const WithdrawState._();

  FiatCurrency get currency {
    return when(
      initial: (_, _) => FiatCurrency.cad,
      amountInput: (userSummary, _, _) => userSummary.currency != null
          ? FiatCurrency.fromCode(userSummary.currency!)
          : FiatCurrency.cad,
      recipientInput: (_, _, currency, _, _, _, _, _) => currency,
      confirmation: (_, _, currency, _, _, _, _) => currency,
      success: (order) => FiatCurrency.fromCode(order.payoutCurrency),
    );
  }

  WithdrawAmountInputState? get cleanAmountInputState {
    return whenOrNull(
      amountInput: (userSummary, hasActiveVirtualIban, useVirtualIban) =>
          WithdrawAmountInputState(
            userSummary: userSummary,
            hasActiveVirtualIban: hasActiveVirtualIban,
            useVirtualIban: useVirtualIban,
          ),
      recipientInput: (
        userSummary,
        amount,
        currency,
        hasActiveVirtualIban,
        useVirtualIban,
        isCreatingWithdrawOrder,
        newRecipientError,
        selectedRecipientError,
      ) =>
          WithdrawAmountInputState(
            userSummary: userSummary,
            hasActiveVirtualIban: hasActiveVirtualIban,
            useVirtualIban: useVirtualIban,
          ),
      confirmation: (
        userSummary,
        amount,
        currency,
        recipient,
        order,
        isConfirmingWithdrawal,
        error,
      ) =>
          WithdrawAmountInputState(userSummary: userSummary),
    );
  }

  WithdrawRecipientInputState? get cleanRecipientInputState {
    return whenOrNull(
      recipientInput: (
        userSummary,
        amount,
        currency,
        hasActiveVirtualIban,
        useVirtualIban,
        isCreatingWithdrawOrder,
        newRecipientError,
        selectedRecipientError,
      ) =>
          WithdrawRecipientInputState(
            userSummary: userSummary,
            amount: amount,
            currency: currency,
            hasActiveVirtualIban: hasActiveVirtualIban,
            useVirtualIban: useVirtualIban,
            isCreatingWithdrawOrder: false,
            newRecipientError: null,
            selectedRecipientError: null,
          ),
      confirmation: (
        userSummary,
        amount,
        currency,
        recipient,
        order,
        isConfirmingWithdrawal,
        error,
      ) =>
          WithdrawRecipientInputState(
            userSummary: userSummary,
            amount: amount,
            currency: currency,
          ),
    );
  }

  WithdrawConfirmationState? get cleanConfirmationState {
    return whenOrNull(
      confirmation: (
        userSummary,
        amount,
        currency,
        recipient,
        order,
        isConfirmingWithdrawal,
        error,
      ) =>
          WithdrawConfirmationState(
            userSummary: userSummary,
            amount: amount,
            currency: currency,
            recipient: recipient,
            order: order,
            error: null,
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
      hasActiveVirtualIban: hasActiveVirtualIban,
      useVirtualIban: useVirtualIban,
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
