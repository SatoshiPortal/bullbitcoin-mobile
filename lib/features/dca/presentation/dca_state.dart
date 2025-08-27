part of 'dca_bloc.dart';

@freezed
sealed class DcaState with _$DcaState {
  const factory DcaState.initial({
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
  }) = DcaInitialState;
  const factory DcaState.amountInput({required UserSummary userSummary}) =
      DcaAmountInputState;
  const factory DcaState.walletSelection({
    required UserSummary userSummary,
    required double amount,
    required FiatCurrency currency,
    //required DcaFrequency frequency,
  }) = DcaWalletSelectionState;
  const factory DcaState.confirmation({
    required UserSummary userSummary,
    required double amount,
    required FiatCurrency currency,
    //required DcaFrequency frequency,
    Wallet? selectedWallet,
    required String destination,
    @Default(false) bool isConfirmingDca,
    // TODO: error
  }) = DcaConfirmationState;
  const factory DcaState.success({required UserSummary userSummary}) =
      DcaSuccessState;
  const DcaState._();

  DcaAmountInputState? get toCleanAmountInputState {
    return whenOrNull(
      amountInput: (userSummary) {
        return DcaAmountInputState(userSummary: userSummary);
      },
      walletSelection: (userSummary, amount, currency) {
        return DcaAmountInputState(userSummary: userSummary);
      },
      confirmation: (
        userSummary,
        amount,
        currency,
        selectedWallet,
        destination,
        isConfirmingDca,
      ) {
        return DcaAmountInputState(userSummary: userSummary);
      },
    );
  }

  DcaWalletSelectionState? get toCleanWalletSelectionState {
    return whenOrNull(
      walletSelection: (userSummary, amount, currency) {
        return DcaWalletSelectionState(
          userSummary: userSummary,
          amount: amount,
          currency: currency,
        );
      },
      confirmation: (
        userSummary,
        amount,
        currency,
        selectedWallet,
        destination,
        isConfirmingDca,
      ) {
        return DcaWalletSelectionState(
          userSummary: userSummary,
          amount: amount,
          currency: currency,
        );
      },
    );
  }

  DcaConfirmationState? get toCleanConfirmationState {
    return whenOrNull(
      confirmation: (
        userSummary,
        amount,
        currency,
        selectedWallet,
        destination,
        isConfirmingDca,
      ) {
        return DcaConfirmationState(
          userSummary: userSummary,
          amount: amount,
          currency: currency,
          selectedWallet: selectedWallet,
          destination: destination,
          isConfirmingDca: isConfirmingDca,
        );
      },
    );
  }

  FiatCurrency get currency {
    return when(
      initial: (apiKeyException, getUserSummaryException) => FiatCurrency.cad,
      amountInput:
          (userSummary) => FiatCurrency.fromCode(userSummary.currency ?? 'CAD'),
      walletSelection: (userSummary, amount, currency) => currency,
      confirmation: (
        userSummary,
        amount,
        currency,
        selectedWallet,
        destination,
        isConfirmingDca,
      ) {
        return currency;
      },
      success:
          (userSummary) => FiatCurrency.cad, // TODO: userSummary.dca.currency,
    );
  }
}

extension DcaAmountInputStateX on DcaAmountInputState {
  DcaWalletSelectionState toWalletSelectionState({
    required double amount,
    required FiatCurrency currency,
  }) {
    return DcaWalletSelectionState(
      userSummary: userSummary,
      amount: amount,
      currency: currency,
    );
  }
}

extension DcaWalletSelectionStateX on DcaWalletSelectionState {
  DcaConfirmationState toConfirmationState({
    Wallet? selectedWallet,
    required String destination,
  }) {
    return DcaConfirmationState(
      userSummary: userSummary,
      amount: amount,
      currency: currency,
      selectedWallet: selectedWallet,
      destination: destination,
    );
  }
}

extension DcaConfirmationStateX on DcaConfirmationState {
  DcaSuccessState toSuccessState({required UserSummary userSummary}) {
    return DcaSuccessState(userSummary: userSummary);
  }
}
