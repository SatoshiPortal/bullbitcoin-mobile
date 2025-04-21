part of 'electrum_settings_bloc.dart';

enum ElectrumSettingsStatus {
  none,
  loading,
  success,
  error,
}

@freezed
class ElectrumAdvancedOptions with _$ElectrumAdvancedOptions {
  const factory ElectrumAdvancedOptions({
    @Default(20) int stopGap,
    @Default(5) int retry,
    @Default(5) int timeout,
  }) = _ElectrumAdvancedOptions;
}

@freezed
class ElectrumSettingsState with _$ElectrumSettingsState {
  const factory ElectrumSettingsState({
    @Default([]) List<ElectrumServer> electrumServers,
    @Default([])
    List<ElectrumServer>
        stagedServers, // Single source of truth for staged changes
    @Default(ElectrumSettingsStatus.none) ElectrumSettingsStatus status,
    @Default(Network.bitcoinMainnet) Network selectedNetwork,
    @Default(ElectrumServerProvider.bullBitcoin)
    ElectrumServerProvider selectedProvider,
    @Default('') String statusError,
    @Default(false) bool saveSuccessful,
  }) = _ElectrumSettingsState;

  const ElectrumSettingsState._();

  bool get isSelectedNetworkLiquid =>
      selectedNetwork == Network.liquidMainnet ||
      selectedNetwork == Network.liquidTestnet;

  bool get isCustomProvider =>
      selectedProvider == ElectrumServerProvider.custom;

  List<String> get serverProviderLabels =>
      const ['Blockstream', 'Bull Bitcoin', 'Custom'];

  int get selectedServerTypeIndex {
    switch (selectedProvider) {
      case ElectrumServerProvider.blockstream:
        return 0;
      case ElectrumServerProvider.bullBitcoin:
        return 1;
      case ElectrumServerProvider.custom:
        return 2;
    }
  }

  // Helper method to get the current server configuration for UI display
  ElectrumServer? getServerForNetworkAndProvider(
      Network network, ElectrumServerProvider provider) {
    // First check in staged servers
    for (final server in stagedServers) {
      if (server.network == network && server.provider == provider) {
        return server;
      }
    }

    // If not in staged servers, check in original electrumServers
    for (final server in electrumServers) {
      if (server.network == network && server.provider == provider) {
        return server;
      }
    }

    // No server found
    return null;
  }

  // Get the validate domain value for the current provider
  bool getValidateDomainForProvider(ElectrumServerProvider provider) {
    // Check in staged servers first
    final stagedServersForProvider =
        stagedServers.where((server) => server.provider == provider).toList();

    if (stagedServersForProvider.isNotEmpty) {
      return stagedServersForProvider.first.validateDomain;
    }

    // Then check in original servers
    final originalServersForProvider =
        electrumServers.where((server) => server.provider == provider).toList();

    if (originalServersForProvider.isNotEmpty) {
      return originalServersForProvider.first.validateDomain;
    }

    // Default
    return false;
  }

  // Check if there are any pending changes
  bool get hasPendingChanges => stagedServers.isNotEmpty;

  // Get all current servers including staged changes
  List<ElectrumServer> get effectiveServers {
    final result = List<ElectrumServer>.from(electrumServers);

    for (final stagedServer in stagedServers) {
      final index = result.indexWhere((server) =>
          server.network == stagedServer.network &&
          server.provider == stagedServer.provider);

      if (index >= 0) {
        // Replace existing server
        result[index] = stagedServer;
      } else {
        // Add new server
        result.add(stagedServer);
      }
    }

    return result;
  }
}
