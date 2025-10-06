part of 'electrum_settings_bloc.dart';

enum ElectrumSettingsStatus { none, loading, success, error }

@freezed
abstract class ElectrumSettingsState with _$ElectrumSettingsState {
  const factory ElectrumSettingsState({
    @Default([]) List<ElectrumServer> electrumServers,
    @Default([]) List<ElectrumServer> stagedServers,
    @Default(<String, String>{})
    Map<String, String> previousUrls, // Map to store previous URLs
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

  bool get isCustomServerSelected =>
      selectedProvider is CustomElectrumServerProvider;

  bool get isTestnet =>
      selectedNetwork == Network.bitcoinTestnet ||
      selectedNetwork == Network.liquidTestnet;

  // Improved server lookup with better provider comparison
  ElectrumServer? getServerForNetworkAndProvider(
    Network network,
    ElectrumServerProvider provider,
  ) {
    // Check staged servers first - these have priority
    for (final server in stagedServers) {
      if (server.network == network &&
          _areProvidersEqual(server.electrumServerProvider, provider)) {
        return server;
      }
    }

    // Then check original servers
    for (final server in electrumServers) {
      if (server.network == network &&
          _areProvidersEqual(server.electrumServerProvider, provider)) {
        return server;
      }
    }

    return null;
  }

  // More precise provider equality check
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

  // Get the validate domain value for a specific provider with better error handling
  bool getValidateDomainForProvider(ElectrumServerProvider provider) {
    // First check in staged servers for the current network type
    final stagedServersForType =
        stagedServers
            .where(
              (server) =>
                  server.electrumServerProvider == provider &&
                  server.network == selectedNetwork,
            )
            .toList();

    if (stagedServersForType.isNotEmpty) {
      return stagedServersForType.first.validateDomain;
    }

    // Then check in original electrumServers for the current network type
    final serversForType =
        electrumServers
            .where(
              (server) =>
                  server.electrumServerProvider == provider &&
                  server.network == selectedNetwork,
            )
            .toList();

    if (serversForType.isNotEmpty) {
      return serversForType.first.validateDomain;
    }

    // Default value
    return true;
  }

  // Get all current servers including staged changes with better merging
  List<ElectrumServer> get effectiveServers {
    final result = <ElectrumServer>[];
    final serverMap = <String, ElectrumServer>{};

    // Add all original servers to the map with a unique key
    for (final server in electrumServers) {
      final key = server.url + server.network.toString();
      serverMap[key] = server;
    }

    // Override or add staged servers
    for (final stagedServer in stagedServers) {
      final key = stagedServer.url + stagedServer.network.toString();
      serverMap[key] = stagedServer;
    }

    // Convert map back to list
    result.addAll(serverMap.values);
    return result;
  }

  // More reliable current server getter for advanced options
  ElectrumServer? get currentServer {
    final mainnetNetwork =
        isSelectedNetworkLiquid
            ? Network.liquidMainnet
            : Network.bitcoinMainnet;

    return getServerForNetworkAndProvider(mainnetNetwork, selectedProvider);
  }
}
