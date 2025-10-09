part of 'electrum_settings_bloc.dart';

// Using freezed here for easy immutability since used in the UI
//  which makes re-rendering more efficient.
@freezed
sealed class ElectrumSettingsState with _$ElectrumSettingsState {
  const factory ElectrumSettingsState({
    @Default(false) bool isLiquid,
    ElectrumEnvironment? environment,
    @Default([]) List<ElectrumServerViewModel> defaultServers,
    @Default([]) List<ElectrumServerViewModel> customServers,
    ElectrumAdvancedOptionsViewModel? advancedOptions,
    @Default(false) bool isLoadingData,
    @Default(false) bool isAddingCustomServer,
    @Default(false) bool isPrioritizingCustomServer,
    @Default(false) bool isDeletingCustomServer,
    @Default(false) bool isSavingAdvancedOptions,
    ElectrumServersException? electrumServersError,
    AdvancedOptionsException? advancedOptionsError,
  }) = _ElectrumSettingsState;
  const ElectrumSettingsState._();

  bool get isLoading =>
      isLoadingData ||
      isAddingCustomServer ||
      isPrioritizingCustomServer ||
      isDeletingCustomServer ||
      isSavingAdvancedOptions;

  List<ElectrumServerViewModel> getServersSortedByPriority({
    required bool isCustom,
  }) {
    final servers = isCustom ? customServers : defaultServers;
    final sortedServers = [...servers];
    sortedServers.sort((a, b) => a.priority.compareTo(b.priority));
    return sortedServers;
  }
}
