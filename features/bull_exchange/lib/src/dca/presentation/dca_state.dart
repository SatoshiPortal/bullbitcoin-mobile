part of 'dca_bloc.dart';

@freezed
sealed class DcaState with _$DcaState {
  const factory DcaState.initial({DcaFailure? failure}) = DcaInitialState;
  const factory DcaState.buyInput({
    required String? defaultLightningAddress,
    required DefaultWallets defaultWallets,
    required List<UserBalance> balances,
    FiatCurrency? currency,
  }) = DcaBuyInputState;
  const factory DcaState.walletSelection({
    required String? defaultLightningAddress,
    required DefaultWallets defaultWallets,
    required List<UserBalance> balances,
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
  }) = DcaWalletSelectionState;
  const factory DcaState.confirmation({
    required String? defaultLightningAddress,
    required DefaultWallets defaultWallets,
    required List<UserBalance> balances,
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required BtcNetwork network,
    required String address,
    @Default(false) bool isDefaultAddress,
    @Default(false) bool isConfirmingDca,
    DcaFailure? failure,
  }) = DcaConfirmationState;
  const factory DcaState.success({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
  }) = DcaSuccessState;
  const DcaState._();

  String? get defaultLightningAddress => switch (this) {
    DcaInitialState() || DcaSuccessState() => null,
    DcaBuyInputState(:final defaultLightningAddress) ||
    DcaWalletSelectionState(:final defaultLightningAddress) ||
    DcaConfirmationState(
      :final defaultLightningAddress,
    ) => defaultLightningAddress,
  };

  DcaBuyInputState? get toCleanBuyInputState => switch (this) {
    DcaInitialState() || DcaSuccessState() => null,
    DcaBuyInputState(
      :final defaultLightningAddress,
      :final defaultWallets,
      :final balances,
      :final currency,
    ) =>
      DcaBuyInputState(
        defaultLightningAddress: defaultLightningAddress,
        defaultWallets: defaultWallets,
        balances: balances,
        currency: currency,
      ),
    DcaWalletSelectionState(
      :final defaultLightningAddress,
      :final defaultWallets,
      :final balances,
      :final currency,
    ) ||
    DcaConfirmationState(
      :final defaultLightningAddress,
      :final defaultWallets,
      :final balances,
      :final currency,
    ) => DcaBuyInputState(
      defaultLightningAddress: defaultLightningAddress,
      defaultWallets: defaultWallets,
      balances: balances,
      currency: currency,
    ),
  };

  DcaWalletSelectionState? get toCleanWalletSelectionState => switch (this) {
    DcaInitialState() || DcaSuccessState() || DcaBuyInputState() => null,
    DcaWalletSelectionState(
      :final defaultLightningAddress,
      :final defaultWallets,
      :final balances,
      :final amount,
      :final currency,
      :final frequency,
    ) ||
    DcaConfirmationState(
      :final defaultLightningAddress,
      :final defaultWallets,
      :final balances,
      :final amount,
      :final currency,
      :final frequency,
    ) => DcaWalletSelectionState(
      defaultLightningAddress: defaultLightningAddress,
      defaultWallets: defaultWallets,
      balances: balances,
      amount: amount,
      currency: currency,
      frequency: frequency,
    ),
  };

  DcaConfirmationState? get toCleanConfirmationState => switch (this) {
    DcaInitialState() ||
    DcaSuccessState() ||
    DcaBuyInputState() ||
    DcaWalletSelectionState() => null,
    final DcaConfirmationState confirmation => DcaConfirmationState(
      defaultLightningAddress: confirmation.defaultLightningAddress,
      defaultWallets: confirmation.defaultWallets,
      balances: confirmation.balances,
      amount: confirmation.amount,
      currency: confirmation.currency,
      frequency: confirmation.frequency,
      network: confirmation.network,
      address: confirmation.address,
      isDefaultAddress: confirmation.isDefaultAddress,
    ),
  };

  FiatCurrency? get currency => switch (this) {
    DcaInitialState() => null,
    DcaBuyInputState(:final currency) => currency,
    DcaWalletSelectionState(:final currency) ||
    DcaConfirmationState(:final currency) ||
    DcaSuccessState(:final currency) => currency,
  };

  List<UserBalance> get balances => switch (this) {
    DcaInitialState() || DcaSuccessState() => const [],
    DcaBuyInputState(:final balances) ||
    DcaWalletSelectionState(:final balances) ||
    DcaConfirmationState(:final balances) => balances,
  };
}

extension DcaBuyInputStateX on DcaBuyInputState {
  DcaWalletSelectionState toWalletSelectionState({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
  }) {
    return DcaWalletSelectionState(
      defaultLightningAddress: defaultLightningAddress,
      defaultWallets: defaultWallets,
      balances: balances,
      amount: amount,
      currency: currency,
      frequency: frequency,
    );
  }
}

extension DcaWalletSelectionStateX on DcaWalletSelectionState {
  DcaConfirmationState toConfirmationState({
    required BtcNetwork network,
    required String address,
    bool isDefaultAddress = false,
  }) {
    return DcaConfirmationState(
      defaultLightningAddress: defaultLightningAddress,
      defaultWallets: defaultWallets,
      balances: balances,
      amount: amount,
      currency: currency,
      frequency: frequency,
      network: network,
      address: address,
      isDefaultAddress: isDefaultAddress,
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
