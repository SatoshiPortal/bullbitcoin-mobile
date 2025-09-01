part of 'dca_bloc.dart';

@freezed
sealed class DcaState with _$DcaState {
  const factory DcaState.initial({
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
  }) = DcaInitialState;
  const factory DcaState.buyInput({required UserSummary userSummary}) =
      DcaBuyInputState;
  const factory DcaState.walletSelection({
    required UserSummary userSummary,
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
  }) = DcaWalletSelectionState;
  const factory DcaState.confirmation({
    required UserSummary userSummary,
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required DcaWalletType selectedWallet,
    String? lightningAddress,
    @Default(false) bool isDefaultLightningAddress,
    @Default(false) bool isConfirmingDca,
    // TODO: error
  }) = DcaConfirmationState;
  const factory DcaState.success({required UserSummary userSummary}) =
      DcaSuccessState;
  const DcaState._();

  DcaBuyInputState? get toCleanBuyInputState {
    return whenOrNull(
      buyInput: (userSummary) {
        return DcaBuyInputState(userSummary: userSummary);
      },
      walletSelection: (userSummary, amount, currency, frequency) {
        return DcaBuyInputState(userSummary: userSummary);
      },
      confirmation: (
        userSummary,
        amount,
        currency,
        frequency,
        selectedWallet,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
      ) {
        return DcaBuyInputState(userSummary: userSummary);
      },
    );
  }

  DcaWalletSelectionState? get toCleanWalletSelectionState {
    return whenOrNull(
      walletSelection: (userSummary, amount, currency, frequency) {
        return DcaWalletSelectionState(
          userSummary: userSummary,
          amount: amount,
          currency: currency,
          frequency: frequency,
        );
      },
      confirmation: (
        userSummary,
        amount,
        currency,
        frequency,
        selectedWallet,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
      ) {
        return DcaWalletSelectionState(
          userSummary: userSummary,
          amount: amount,
          currency: currency,
          frequency: frequency,
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
        frequency,
        selectedWallet,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
      ) {
        return DcaConfirmationState(
          userSummary: userSummary,
          amount: amount,
          currency: currency,
          frequency: frequency,
          selectedWallet: selectedWallet,
          lightningAddress: lightningAddress,
          isDefaultLightningAddress: isDefaultLightningAddress,
          isConfirmingDca: isConfirmingDca,
        );
      },
    );
  }

  FiatCurrency get currency {
    return when(
      initial: (apiKeyException, getUserSummaryException) => FiatCurrency.cad,
      buyInput:
          (userSummary) => FiatCurrency.fromCode(userSummary.currency ?? 'CAD'),
      walletSelection: (userSummary, amount, currency, frequency) => currency,
      confirmation: (
        userSummary,
        amount,
        currency,
        frequency,
        selectedWallet,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
      ) {
        return currency;
      },
      success:
          (userSummary) => FiatCurrency.cad, // TODO: userSummary.dca.currency,
    );
  }

  List<UserBalance> get balances => when(
    initial: (apiKeyException, getUserSummaryException) => [],
    buyInput: (userSummary) => userSummary.balances,
    walletSelection:
        (userSummary, amount, currency, frequency) => userSummary.balances,
    confirmation: (
      userSummary,
      amount,
      currency,
      frequency,
      selectedWallet,
      lightningAddress,
      isDefaultLightningAddress,
      isConfirmingDca,
    ) {
      return userSummary.balances;
    },
    success: (userSummary) => userSummary.balances,
  );
}

extension DcaBuyInputStateX on DcaBuyInputState {
  DcaWalletSelectionState toWalletSelectionState({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
  }) {
    return DcaWalletSelectionState(
      userSummary: userSummary,
      amount: amount,
      currency: currency,
      frequency: frequency,
    );
  }
}

extension DcaWalletSelectionStateX on DcaWalletSelectionState {
  DcaConfirmationState toConfirmationState({
    required DcaWalletType selectedWallet,
    String? lightningAddress,
    bool isDefaultLightningAddress = false,
  }) {
    return DcaConfirmationState(
      userSummary: userSummary,
      amount: amount,
      currency: currency,
      frequency: frequency,
      selectedWallet: selectedWallet,
      lightningAddress: lightningAddress,
      isDefaultLightningAddress: isDefaultLightningAddress,
    );
  }
}

extension DcaConfirmationStateX on DcaConfirmationState {
  DcaSuccessState toSuccessState({required UserSummary userSummary}) {
    return DcaSuccessState(userSummary: userSummary);
  }
}
