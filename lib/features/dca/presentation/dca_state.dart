part of 'dca_bloc.dart';

@freezed
sealed class DcaState with _$DcaState {
  const factory DcaState.initial({
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
  }) = DcaInitialState;
  const factory DcaState.buyInput({
    required String? defaultLightningAddress,
    required List<UserBalance> balances,
    FiatCurrency? currency,
  }) = DcaBuyInputState;
  const factory DcaState.walletSelection({
    required String? defaultLightningAddress,
    required List<UserBalance> balances,
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
  }) = DcaWalletSelectionState;
  const factory DcaState.confirmation({
    required String? defaultLightningAddress,
    required List<UserBalance> balances,
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
      buyInput:
          (defaultLightningAddress, balances, currency) =>
              defaultLightningAddress,
      walletSelection:
          (defaultLightningAddress, balances, amount, currency, frequency) =>
              defaultLightningAddress,
      confirmation: (
        defaultLightningAddress,
        balances,
        amount,
        currency,
        frequency,
        network,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
        error,
      ) {
        return defaultLightningAddress;
      },
      success: (amount, currency, frequency) => null,
    );
  }

  DcaBuyInputState? get toCleanBuyInputState {
    return whenOrNull(
      buyInput: (defaultLightningAddress, balances, currency) {
        return DcaBuyInputState(
          defaultLightningAddress: defaultLightningAddress,
          balances: balances,
          currency: currency,
        );
      },
      walletSelection: (
        defaultLightningAddress,
        balances,
        amount,
        currency,
        frequency,
      ) {
        return DcaBuyInputState(
          defaultLightningAddress: defaultLightningAddress,
          balances: balances,
          currency: currency,
        );
      },
      confirmation: (
        defaultLightningAddress,
        balances,
        amount,
        currency,
        frequency,
        network,
        lightningAddress,
        isDefaultLightningAddress,
        isConfirmingDca,
        error,
      ) {
        return DcaBuyInputState(
          defaultLightningAddress: defaultLightningAddress,
          balances: balances,
          currency: currency,
        );
      },
    );
  }

  DcaWalletSelectionState? get toCleanWalletSelectionState {
    return whenOrNull(
      walletSelection: (
        defaultLightningAddress,
        balances,
        amount,
        currency,
        frequency,
      ) {
        return DcaWalletSelectionState(
          defaultLightningAddress: defaultLightningAddress,
          balances: balances,
          amount: amount,
          currency: currency,
          frequency: frequency,
        );
      },
      confirmation: (
        defaultLightningAddress,
        balances,
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
          defaultLightningAddress: defaultLightningAddress,
          balances: balances,
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
        defaultLightningAddress,
        balances,
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
          defaultLightningAddress: defaultLightningAddress,
          balances: balances,
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

  FiatCurrency? get currency {
    return when(
      initial: (apiKeyException, getUserSummaryException) => null,
      buyInput: (defaultLightningAddress, balances, currency) => currency,
      walletSelection:
          (defaultLightningAddress, balances, amount, currency, frequency) =>
              currency,
      confirmation: (
        defaultLightningAddress,
        balances,
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
    buyInput: (defaultLightningAddress, balances, currency) => balances,
    walletSelection:
        (defaultLightningAddress, balances, amount, currency, frequency) =>
            balances,
    confirmation: (
      defaultLightningAddress,
      balances,
      amount,
      currency,
      frequency,
      network,
      lightningAddress,
      isDefaultLightningAddress,
      isConfirmingDca,
      error,
    ) {
      return balances;
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
      defaultLightningAddress: defaultLightningAddress,
      balances: balances,
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
      defaultLightningAddress: defaultLightningAddress,
      balances: balances,
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
