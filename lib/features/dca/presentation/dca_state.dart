part of 'dca_bloc.dart';

@freezed
sealed class DcaState with _$DcaState {
  const factory DcaState.initial({DcaFailure? failure}) = DcaInitialState;
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
    DcaFailure? failure,
  }) = DcaConfirmationState;
  const factory DcaState.success({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
  }) = DcaSuccessState;
  const DcaState._();

  String? get defaultLightningAddress {
    return when(
      initial: (failure) => null,
      buyInput: (defaultLightningAddress, balances, currency) =>
          defaultLightningAddress,
      walletSelection:
          (defaultLightningAddress, balances, amount, currency, frequency) =>
              defaultLightningAddress,
      confirmation:
          (
            defaultLightningAddress,
            balances,
            amount,
            currency,
            frequency,
            network,
            lightningAddress,
            isDefaultLightningAddress,
            isConfirmingDca,
            failure,
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
      walletSelection:
          (defaultLightningAddress, balances, amount, currency, frequency) {
            return DcaBuyInputState(
              defaultLightningAddress: defaultLightningAddress,
              balances: balances,
              currency: currency,
            );
          },
      confirmation:
          (
            defaultLightningAddress,
            balances,
            amount,
            currency,
            frequency,
            network,
            lightningAddress,
            isDefaultLightningAddress,
            isConfirmingDca,
            failure,
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
      walletSelection:
          (defaultLightningAddress, balances, amount, currency, frequency) {
            return DcaWalletSelectionState(
              defaultLightningAddress: defaultLightningAddress,
              balances: balances,
              amount: amount,
              currency: currency,
              frequency: frequency,
            );
          },
      confirmation:
          (
            defaultLightningAddress,
            balances,
            amount,
            currency,
            frequency,
            network,
            lightningAddress,
            isDefaultLightningAddress,
            isConfirmingDca,
            failure,
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
      confirmation:
          (
            defaultLightningAddress,
            balances,
            amount,
            currency,
            frequency,
            network,
            lightningAddress,
            isDefaultLightningAddress,
            isConfirmingDca,
            failure,
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
              failure: null,
            );
          },
    );
  }

  FiatCurrency? get currency {
    return when(
      initial: (failure) => null,
      buyInput: (defaultLightningAddress, balances, currency) => currency,
      walletSelection:
          (defaultLightningAddress, balances, amount, currency, frequency) =>
              currency,
      confirmation:
          (
            defaultLightningAddress,
            balances,
            amount,
            currency,
            frequency,
            network,
            lightningAddress,
            isDefaultLightningAddress,
            isConfirmingDca,
            failure,
          ) {
            return currency;
          },
      success: (amount, currency, frequency) => currency,
    );
  }

  List<UserBalance> get balances => when(
    initial: (failure) => [],
    buyInput: (defaultLightningAddress, balances, currency) => balances,
    walletSelection:
        (defaultLightningAddress, balances, amount, currency, frequency) =>
            balances,
    confirmation:
        (
          defaultLightningAddress,
          balances,
          amount,
          currency,
          frequency,
          network,
          lightningAddress,
          isDefaultLightningAddress,
          isConfirmingDca,
          failure,
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
