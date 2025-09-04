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
    required DcaNetwork network,
    String? lightningAddress,
    @Default(false) bool isDefaultLightningAddress,
    @Default(false) bool isConfirmingDca,
    Object? error,
  }) = DcaConfirmationState;
  const factory DcaState.success({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
  }) = DcaSuccessState;
  const DcaState._();

  String? get defaultLightningAddress {
    return when(
      initial: (apiKeyException, getUserSummaryException) => null,
      buyInput: (userSummary) => userSummary.autoBuy.addresses.lightning,
      walletSelection:
          (userSummary, amount, currency, frequency) =>
              userSummary.autoBuy.addresses.lightning,
      confirmation: (
        userSummary,
        amount,
        currency,
        frequency,
        network,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
        error,
      ) {
        return userSummary.autoBuy.addresses.lightning;
      },
      success: (amount, currency, frequency) => null,
    );
  }

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
        network,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
        error,
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
        network,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
        error,
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
        network,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
        error,
      ) {
        return DcaConfirmationState(
          userSummary: userSummary,
          amount: amount,
          currency: currency,
          frequency: frequency,
          network: network,
          lightningAddress: lightningAddress,
          isDefaultLightningAddress: isDefaultLightningAddress,
          isConfirmingDca: false,
          error: null,
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
        network,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
        error,
      ) {
        return currency;
      },
      success: (amount, currency, frequency) => currency,
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
      network,
      lightningAddress,
      isDefaultLightningAddress,
      isConfirmingDca,
      error,
    ) {
      return userSummary.balances;
    },
    success: (amount, currency, frequency) => [],
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
    required DcaNetwork network,
    String? lightningAddress,
    bool isDefaultLightningAddress = false,
  }) {
    return DcaConfirmationState(
      userSummary: userSummary,
      amount: amount,
      currency: currency,
      frequency: frequency,
      network: network,
      lightningAddress: lightningAddress,
      isDefaultLightningAddress: isDefaultLightningAddress,
    );
  }
}

extension DcaConfirmationStateX on DcaConfirmationState {
  DcaSuccessState toSuccessState({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
  }) {
    return DcaSuccessState(
      amount: amount,
      currency: currency,
      frequency: frequency,
    );
  }
}
