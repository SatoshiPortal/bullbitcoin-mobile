part of 'electrum_settings_bloc.dart';

// Using freezed here for easy immutability since used in the UI
//  which makes re-rendering more efficient.
@freezed
sealed class ElectrumSettingsState with _$ElectrumSettingsState {
  const factory ElectrumSettingsState.loading({
    @Default([]) List<ElectrumServerViewModel> defaultBitcoinServers,
    @Default([]) List<ElectrumServerViewModel> customBitcoinServers,
    @Default([]) List<ElectrumServerViewModel> defaultLiquidServers,
    @Default([]) List<ElectrumServerViewModel> customLiquidServers,
    ElectrumAdvancedOptionsViewModel? bitcoinAdvancedOptions,
    ElectrumAdvancedOptionsViewModel? liquidAdvancedOptions,
  }) = ElectrumSettingsLoadingState;
  const factory ElectrumSettingsState.loaded({
    required List<ElectrumServerViewModel> defaultBitcoinServers,
    required List<ElectrumServerViewModel> customBitcoinServers,
    required List<ElectrumServerViewModel> defaultLiquidServers,
    required List<ElectrumServerViewModel> customLiquidServers,
    ElectrumAdvancedOptionsViewModel? bitcoinAdvancedOptions,
    ElectrumAdvancedOptionsViewModel? liquidAdvancedOptions,
    @Default(false) bool isAddingCustomServer,
    @Default(false) bool isPrioritizingCustomServer,
    @Default(false) bool isDeletingCustomServer,
    @Default(false) bool isSavingAdvancedOptions,
    ElectrumServersError? electrumServersError,
    NewCustomServerError? newCustomServerError,
    AdvancedOptionsError? advancedOptionsError,
  }) = ElectrumSettingsLoadedState;
  const ElectrumSettingsState._();

  bool get isAddingCustomServerInProgress => maybeMap(
    loaded: (state) => state.isAddingCustomServer,
    orElse: () => false,
  );

  bool get isPrioritizingCustomServersInProgress => maybeMap(
    loaded: (state) => state.isPrioritizingCustomServer,
    orElse: () => false,
  );

  bool get isDeletingCustomServerInProgress => maybeMap(
    loaded: (state) => state.isDeletingCustomServer,
    orElse: () => false,
  );

  bool get isSavingAdvancedOptionsInProgress => maybeMap(
    loaded: (state) => state.isSavingAdvancedOptions,
    orElse: () => false,
  );

  ElectrumSettingsLoadingState toLoadingState() {
    return ElectrumSettingsLoadingState(
      defaultBitcoinServers: defaultBitcoinServers,
      customBitcoinServers: customBitcoinServers,
      defaultLiquidServers: defaultLiquidServers,
      customLiquidServers: customLiquidServers,
      bitcoinAdvancedOptions: bitcoinAdvancedOptions,
      liquidAdvancedOptions: liquidAdvancedOptions,
    );
  }
}
