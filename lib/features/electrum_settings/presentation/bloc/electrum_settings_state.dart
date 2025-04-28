part of 'electrum_settings_bloc.dart';

enum ElectrumSettingsStatus {
  none,
  loading,
  success,
  error,
}

@freezed
class ElectrumSettingsState with _$ElectrumSettingsState {
  const factory ElectrumSettingsState({
    @Default([]) List<ElectrumServer> electrumServers,
    @Default([]) List<ElectrumServer> stagedServers,
    @Default(ElectrumSettingsStatus.none) ElectrumSettingsStatus status,
    @Default(Network.bitcoinMainnet) Network selectedNetwork,
    @Default(ElectrumServerProvider.defaultProvider())
    ElectrumServerProvider selectedProvider,
    @Default('') String statusError,
    @Default(false) bool saveSuccessful,
  }) = _ElectrumSettingsState;

  const ElectrumSettingsState._();

  bool get isSelectedNetworkLiquid =>
      selectedNetwork == Network.liquidMainnet ||
      selectedNetwork == Network.liquidTestnet;

  // Helper to check if the selected provider is custom
  bool get isCustomServerSelected =>
      selectedProvider is CustomElectrumServerProvider;

  // Helper to get the default provider value if it's a default provider, or null if custom
  DefaultElectrumServerProvider get selectedDefaultPreset =>
      selectedProvider is DefaultServerProvider
          ? (selectedProvider as DefaultServerProvider).defaultServerProvider
          : DefaultElectrumServerProvider.bullBitcoin;

  // Helper method to get the current server configuration for UI display
  ElectrumServer? getServerForNetworkAndProvider(
    Network network,
    ElectrumServerProvider provider,
  ) {
    // First check in staged servers
    for (final server in stagedServers) {
      if (server.network == network &&
          _areProvidersEqual(server.electrumServerProvider, provider)) {
        return server;
      }
    }

    // If not in staged servers, check in original electrumServers
    for (final server in electrumServers) {
      if (server.network == network &&
          _areProvidersEqual(server.electrumServerProvider, provider)) {
        return server;
      }
    }

    return null;
  }

  // Get the validate domain value for a specific provider
  bool getValidateDomainForProvider(ElectrumServerProvider provider) {
    List<ElectrumServer> serversToCheck = [];

    // Get all servers of the specified provider type
    serversToCheck = [
      ...stagedServers.where(
        (server) => _areProvidersEqual(server.electrumServerProvider, provider),
      ),
      ...electrumServers.where(
        (server) => _areProvidersEqual(server.electrumServerProvider, provider),
      ),
    ];

    // Filter for the current network type (Bitcoin/Liquid)
    final serversForNetworkType = serversToCheck
        .where((server) => _isSameNetworkType(server.network, selectedNetwork))
        .toList();

    if (serversForNetworkType.isNotEmpty) {
      return serversForNetworkType.first.validateDomain;
    }

    // Default
    return true;
  }

  // Helper method to check if two networks are of the same type (Bitcoin/Liquid)
  bool _isSameNetworkType(Network network1, Network network2) {
    return network1.isBitcoin == network2.isBitcoin &&
        network1.isLiquid == network2.isLiquid;
  }

  // Helper to compare ElectrumServerProvider objects
  bool _areProvidersEqual(ElectrumServerProvider a, ElectrumServerProvider b) {
    if (a is CustomElectrumServerProvider &&
        b is CustomElectrumServerProvider) {
      return true;
    }
    if (a is DefaultServerProvider && b is DefaultServerProvider) {
      return a.defaultServerProvider == b.defaultServerProvider;
    }
    return false;
  }

  // Simplified version of hasPendingChanges
  bool get hasPendingChanges {
    // The simple check - do we have any staged changes?
    return stagedServers.isNotEmpty;
  }

  // Get all current servers including staged changes
  List<ElectrumServer> get effectiveServers {
    final result = List<ElectrumServer>.from(electrumServers);

    for (final stagedServer in stagedServers) {
      final index = result.indexWhere(
        (server) =>
            server.network == stagedServer.network &&
            _areProvidersEqual(
              server.electrumServerProvider,
              stagedServer.electrumServerProvider,
            ),
      );

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

  // Get the current server for advanced options
  ElectrumServer? get currentServer {
    final mainnetNetwork = isSelectedNetworkLiquid
        ? Network.liquidMainnet
        : Network.bitcoinMainnet;

    return getServerForNetworkAndProvider(mainnetNetwork, selectedProvider);
  }
}
