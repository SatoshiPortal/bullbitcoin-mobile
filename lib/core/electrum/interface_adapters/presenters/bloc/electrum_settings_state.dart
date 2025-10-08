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
    required ElectrumEnvironment environment,
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
    ElectrumServersException? electrumServersError,
    AdvancedOptionsException? advancedOptionsError,
  }) = ElectrumSettingsLoadedState;
  const ElectrumSettingsState._();

  ElectrumEnvironment? get environment =>
      maybeMap(loaded: (state) => state.environment, orElse: () => null);

  bool get isAddingCustomServer => maybeMap(
    loaded: (state) => state.isAddingCustomServer,
    orElse: () => false,
  );

  bool get isPrioritizingCustomServer => maybeMap(
    loaded: (state) => state.isPrioritizingCustomServer,
    orElse: () => false,
  );

  bool get isDeletingCustomServer => maybeMap(
    loaded: (state) => state.isDeletingCustomServer,
    orElse: () => false,
  );

  bool get isSavingAdvancedOptions => maybeMap(
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

  List<ElectrumServerViewModel> getServersSortedByPriority({
    required bool isLiquid,
    required bool isCustom,
  }) {
    final servers =
        isLiquid
            ? (isCustom
                ? customLiquidServers
                : [...defaultLiquidServers, ...customLiquidServers])
            : (isCustom
                ? customBitcoinServers
                : [...defaultBitcoinServers, ...customBitcoinServers]);

    final sortedServers = [...servers];
    sortedServers.sort((a, b) => a.priority.compareTo(b.priority));
    return sortedServers;
  }
}
