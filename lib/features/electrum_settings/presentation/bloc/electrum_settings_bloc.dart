import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/check_electrum_server_connectivity_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/delete_electrum_server_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_all_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_prioritized_server_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/store_electrum_server_settings_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/try_connection_with_fallback_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/update_electrum_server_settings_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' show Network;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

@freezed
part 'electrum_settings_bloc.freezed.dart';
part 'electrum_settings_event.dart';
part 'electrum_settings_state.dart';

class ElectrumSettingsBloc
    extends Bloc<ElectrumSettingsEvent, ElectrumSettingsState> {
  final GetAllElectrumServersUsecase _getAllElectrumServers;
  final StoreElectrumServerSettingsUsecase _storeElectrumServerSettings;
  final GetPrioritizedServerUsecase _getPrioritizedServerUsecase;
  final CheckElectrumServerConnectivityUsecase _checkElectrumServerConnectivity;
  final UpdateElectrumServerSettingsUsecase _updateElectrumServerSettings;
  final TryConnectionWithFallbackUsecase _tryConnectionWithFallback;
  final DeleteElectrumServerUsecase _deleteElectrumServer;
  ElectrumSettingsBloc({
    required GetAllElectrumServersUsecase getAllElectrumServers,
    required StoreElectrumServerSettingsUsecase storeElectrumServerSettings,
    required UpdateElectrumServerSettingsUsecase updateElectrumServerSettings,
    required GetPrioritizedServerUsecase getPrioritizedServerUsecase,
    required CheckElectrumServerConnectivityUsecase
    checkElectrumServerConnectivity,
    required TryConnectionWithFallbackUsecase tryConnectionWithFallback,
    required DeleteElectrumServerUsecase deleteElectrumServer,
  }) : _getAllElectrumServers = getAllElectrumServers,
       _storeElectrumServerSettings = storeElectrumServerSettings,
       _getPrioritizedServerUsecase = getPrioritizedServerUsecase,
       _checkElectrumServerConnectivity = checkElectrumServerConnectivity,
       _updateElectrumServerSettings = updateElectrumServerSettings,
       _tryConnectionWithFallback = tryConnectionWithFallback,
       _deleteElectrumServer = deleteElectrumServer,
       super(const ElectrumSettingsState()) {
    on<LoadServers>(_onLoadServers);
    on<CheckServerStatus>(_onCheckServerStatus);
    on<ConfigureLiquidSettings>(_onConfigureLiquidSettings);
    on<ConfigureBitcoinSettings>(_onConfigureBitcoinSettings);
    on<UpdateCustomServerMainnet>(_onUpdateCustomServerMainnet);
    on<UpdateCustomServerTestnet>(_onUpdateCustomServerTestnet);
    on<ToggleTestnet>(_onToggleTestnet);
    on<ReorderServers>(_onReorderServers);
    on<SetPrimaryServer>(_onSetPrimaryServer);
    on<UpdateElectrumAdvancedOptions>(_onUpdateElectrumAdvancedOptions);
    on<ToggleSelectedProvider>(_onToggleSelectedProvider);
    on<ToggleValidateDomain>(_onToggleDomainValidation);
    on<SaveElectrumServerChanges>(_onSaveElectrumServerChanges);
    on<ToggleCustomServerActive>(_onToggleCustomServerActive);
    on<ToggleDefaultServerProvider>(_onToggleDefaultServerProvider);
    on<ToggleCustomServer>(_onToggleCustomServer);
    on<DeleteCustomServer>(_onDeleteCustomServer);
  }

  Future<void> _onLoadServers(
    LoadServers event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    try {
      emit(state.copyWith(status: ElectrumSettingsStatus.loading));

      final List<ElectrumServer> allServers = [];
      final networks =
          state.isSelectedNetworkLiquid
              ? [Network.liquidMainnet, Network.liquidTestnet]
              : [Network.bitcoinMainnet, Network.bitcoinTestnet];

      for (final network in networks) {
        final servers = await _getAllElectrumServers.execute(network: network);
        allServers.addAll(servers);
      }

      // First emit state without checking connectivity
      if (allServers.isEmpty) {
        emit(
          state.copyWith(
            status: ElectrumSettingsStatus.error,
            statusError: 'No servers available',
          ),
        );
        return;
      }

      final prioritizedServer = await _getPrioritizedServerUsecase.execute(
        network: state.selectedNetwork,
      );

      emit(
        state.copyWith(
          electrumServers: allServers,
          selectedProvider: prioritizedServer.electrumServerProvider,
          status: ElectrumSettingsStatus.success,
        ),
      );

      add(ToggleSelectedProvider(prioritizedServer.electrumServerProvider));
    } catch (e) {
      log.severe('Error loading servers: $e');
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'Failed to load servers',
        ),
      );
    }
  }

  Future<void> _onCheckServerStatus(
    CheckServerStatus event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    try {
      emit(state.copyWith(status: ElectrumSettingsStatus.loading));

      if (state.electrumServers.isEmpty) {
        emit(
          state.copyWith(
            status: ElectrumSettingsStatus.error,
            statusError: 'No servers available',
          ),
        );
        return;
      }

      final serversToCheck =
          state.electrumServers
              .where((s) => s.network == event.network)
              .toList();

      if (serversToCheck.isEmpty) {
        emit(state.copyWith(status: ElectrumSettingsStatus.success));
        return;
      }

      // Try connection with fallback logic
      final (updatedServers, successfulIndex) = await _tryConnectionWithFallback
          .execute(servers: serversToCheck);

      if (!emit.isDone) {
        // Update all servers with their new status
        final allServers = List<ElectrumServer>.from(state.electrumServers);
        for (final updatedServer in updatedServers) {
          final index = allServers.indexWhere(
            (s) => _isSameServer(s, updatedServer),
          );
          if (index >= 0) {
            allServers[index] = updatedServer;
          }
        }

        emit(
          state.copyWith(
            status: ElectrumSettingsStatus.success,
            electrumServers: allServers,
          ),
        );

        // If a successful server was found, suggest making it the primary
        if (successfulIndex != null) {
          final successfulServer = updatedServers[successfulIndex];
          add(SetPrimaryServer(server: successfulServer));
        }
      }
    } catch (e) {
      log.severe('Error checking server status: $e');
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'Failed to check server status',
        ),
      );
    }
  }

  void _onConfigureLiquidSettings(
    ConfigureLiquidSettings event,
    Emitter<ElectrumSettingsState> emit,
  ) {
    emit(
      state.copyWith(
        status: ElectrumSettingsStatus.loading,
        selectedNetwork: Network.liquidMainnet,
      ),
    );
    add(LoadServers());
  }

  void _onToggleTestnet(
    ToggleTestnet event,
    Emitter<ElectrumSettingsState> emit,
  ) {
    final isCurrentlyTestnet =
        state.selectedNetwork == Network.bitcoinTestnet ||
        state.selectedNetwork == Network.liquidTestnet;

    final newNetwork =
        state.isSelectedNetworkLiquid
            ? (isCurrentlyTestnet
                ? Network.liquidMainnet
                : Network.liquidTestnet)
            : (isCurrentlyTestnet
                ? Network.bitcoinMainnet
                : Network.bitcoinTestnet);

    emit(
      state.copyWith(
        status: ElectrumSettingsStatus.loading,
        selectedNetwork: newNetwork,
      ),
    );
    add(LoadServers());
  }

  void _onConfigureBitcoinSettings(
    ConfigureBitcoinSettings event,
    Emitter<ElectrumSettingsState> emit,
  ) {
    emit(
      state.copyWith(
        status: ElectrumSettingsStatus.loading,
        selectedNetwork: Network.bitcoinMainnet,
      ),
    );
    add(LoadServers());
  }

  Future<void> _onToggleSelectedProvider(
    ToggleSelectedProvider event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    emit(state.copyWith(selectedProvider: event.provider, statusError: ''));

    final updatedElectrumServers = List<ElectrumServer>.from(
      state.electrumServers,
    );

    final mainnetNetwork =
        state.isSelectedNetworkLiquid
            ? Network.liquidMainnet
            : Network.bitcoinMainnet;

    final mainnetServer = state.getServerForNetworkAndProvider(
      mainnetNetwork,
      event.provider,
    );

    if (mainnetServer != null && mainnetServer.url.isNotEmpty) {
      try {
        final status = await _checkElectrumServerStatus(mainnetServer);
        emit(state.copyWith(status: ElectrumSettingsStatus.loading));
        final index = updatedElectrumServers.indexWhere(
          (s) => _isSameServer(s, mainnetServer),
        );

        if (index >= 0 && !emit.isDone) {
          updatedElectrumServers[index] = updatedElectrumServers[index]
              .copyWith(status: status);

          emit(
            state.copyWith(
              electrumServers: updatedElectrumServers,
              status: ElectrumSettingsStatus.success,
            ),
          );
        }
      } catch (e) {
        log.severe('Error checking server connectivity: $e');
      }
    }

    if (event.provider is CustomElectrumServerProvider) {
      final List<ElectrumServer> updatedStagedServers =
          List<ElectrumServer>.from(state.stagedServers);

      final hasMainnetServer =
          state.getServerForNetworkAndProvider(
            mainnetNetwork,
            event.provider,
          ) !=
          null;

      if (!hasMainnetServer) {
        updatedStagedServers.add(
          ElectrumServer(
            url: "",
            network: mainnetNetwork,
            validateDomain: false,
          ),
        );
      }

      final testnetNetwork =
          state.isSelectedNetworkLiquid
              ? Network.liquidTestnet
              : Network.bitcoinTestnet;

      final hasTestnetServer =
          state.getServerForNetworkAndProvider(
            testnetNetwork,
            event.provider,
          ) !=
          null;

      if (!hasTestnetServer) {
        updatedStagedServers.add(
          ElectrumServer(
            url: "",
            network: testnetNetwork,
            validateDomain: false,
          ),
        );
      }

      if (updatedStagedServers.length > state.stagedServers.length) {
        emit(state.copyWith(stagedServers: updatedStagedServers));
      }
    } else if (event.provider is DefaultServerProvider) {
      final defaultProvider =
          (event.provider as DefaultServerProvider).defaultServerProvider;

      await Future.microtask(() async {
        final serversToCheck =
            state.electrumServers.where((s) {
              final provider = s.electrumServerProvider;
              if (provider is DefaultServerProvider) {
                return provider.defaultServerProvider == defaultProvider &&
                    _isSameNetworkType(s.network, state.selectedNetwork);
              }
              return false;
            }).toList();

        for (final server in serversToCheck) {
          if (server.url.isEmpty) continue;

          final status = await _checkElectrumServerStatus(server);

          final index = updatedElectrumServers.indexWhere(
            (s) => _isSameServer(s, server),
          );

          if (index >= 0 && !emit.isDone) {
            updatedElectrumServers[index] = updatedElectrumServers[index]
                .copyWith(status: status);

            emit(state.copyWith(electrumServers: updatedElectrumServers));
          }
        }
      });
    }

    if (!emit.isDone) {
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.success,
          electrumServers: updatedElectrumServers,
        ),
      );
    }
  }

  Future<void> _onUpdateCustomServerMainnet(
    UpdateCustomServerMainnet event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    if (state.selectedProvider is! CustomElectrumServerProvider) return;

    if (state.status == ElectrumSettingsStatus.error) {
      emit(
        state.copyWith(status: ElectrumSettingsStatus.success, statusError: ''),
      );
    }

    final List<ElectrumServer> updatedStagedServers = List<ElectrumServer>.from(
      state.stagedServers,
    );

    final customServer = event.customServer.trim();
    final network =
        state.isSelectedNetworkLiquid
            ? Network.liquidMainnet
            : Network.bitcoinMainnet;

    // Only check for duplicate URL if non-empty
    final urlExists = customServer.isNotEmpty && _isSavedToDb(customServer);

    if (urlExists) {
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'Mainnet: URL is already in use',
        ),
      );
      return;
    }

    // Create a key to track the server by network
    final serverKey = "custom_${network.name}";
    final Map<String, String> updatedPreviousUrls = Map<String, String>.from(
      state.previousUrls,
    );

    // Find original server URL from database (electrumServers)
    final originalServer = state.electrumServers.firstWhere(
      (server) =>
          server.network == network &&
          server.electrumServerProvider is CustomElectrumServerProvider,
      orElse: () => ElectrumServer(url: "", network: network),
    );

    // Store the original URL for later use in update operation
    if (originalServer.url.isNotEmpty) {
      updatedPreviousUrls[serverKey] = originalServer.url;
    }

    final int stagedIndex = updatedStagedServers.indexWhere(
      (server) =>
          server.network == network &&
          server.electrumServerProvider is CustomElectrumServerProvider,
    );

    if (stagedIndex >= 0) {
      updatedStagedServers[stagedIndex] = updatedStagedServers[stagedIndex]
          .copyWith(url: customServer, isActive: customServer.isNotEmpty);
    } else {
      final existingServer = state.getServerForNetworkAndProvider(
        network,
        const ElectrumServerProvider.customProvider(),
      );

      if (existingServer != null) {
        updatedStagedServers.add(
          existingServer.copyWith(
            url: customServer,
            isActive: customServer.isNotEmpty,
          ),
        );
      } else {
        updatedStagedServers.add(
          ElectrumServer(
            url: customServer,
            network: network,
            validateDomain: state.getValidateDomainForProvider(
              state.selectedProvider,
            ),
            isActive: customServer.isNotEmpty,
          ),
        );
      }
    }

    emit(
      state.copyWith(
        stagedServers: updatedStagedServers,
        previousUrls: updatedPreviousUrls,
        status: ElectrumSettingsStatus.success,
      ),
    );
  }

  Future<void> _onUpdateCustomServerTestnet(
    UpdateCustomServerTestnet event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    if (state.selectedProvider is! CustomElectrumServerProvider) return;

    if (state.status == ElectrumSettingsStatus.error) {
      emit(
        state.copyWith(status: ElectrumSettingsStatus.success, statusError: ''),
      );
    }

    final List<ElectrumServer> updatedStagedServers = List<ElectrumServer>.from(
      state.stagedServers,
    );

    final customServer = event.customServer.trim();
    final network =
        state.isSelectedNetworkLiquid
            ? Network.liquidTestnet
            : Network.bitcoinTestnet;

    // Only check for duplicate URL if non-empty
    final urlExists = customServer.isNotEmpty && _isSavedToDb(customServer);
    if (urlExists) {
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'Testnet: URL is already in use',
        ),
      );
      return;
    }

    // Create a key to track the server by network
    final serverKey = "custom_${network.name}";
    final Map<String, String> updatedPreviousUrls = Map<String, String>.from(
      state.previousUrls,
    );

    // Find original server URL from database (electrumServers)
    final originalServer = state.electrumServers.firstWhere(
      (server) =>
          server.network == network &&
          server.electrumServerProvider is CustomElectrumServerProvider,
      orElse: () => ElectrumServer(url: "", network: network),
    );

    // Store the original URL for later use in update operation
    if (originalServer.url.isNotEmpty) {
      updatedPreviousUrls[serverKey] = originalServer.url;
    }

    final int stagedIndex = updatedStagedServers.indexWhere(
      (server) =>
          server.network == network &&
          server.electrumServerProvider is CustomElectrumServerProvider,
    );

    if (stagedIndex >= 0) {
      updatedStagedServers[stagedIndex] = updatedStagedServers[stagedIndex]
          .copyWith(url: customServer, isActive: customServer.isNotEmpty);
    } else {
      final existingServer = state.getServerForNetworkAndProvider(
        network,
        const ElectrumServerProvider.customProvider(),
      );

      if (existingServer != null) {
        updatedStagedServers.add(
          existingServer.copyWith(
            url: customServer,
            isActive: customServer.isNotEmpty,
          ),
        );
      } else {
        updatedStagedServers.add(
          ElectrumServer(
            url: customServer,
            network: network,
            validateDomain: state.getValidateDomainForProvider(
              state.selectedProvider,
            ),
            isActive: customServer.isNotEmpty,
          ),
        );
      }
    }

    emit(
      state.copyWith(
        stagedServers: updatedStagedServers,
        previousUrls: updatedPreviousUrls,
        status: ElectrumSettingsStatus.success,
      ),
    );
  }

  void _onUpdateElectrumAdvancedOptions(
    UpdateElectrumAdvancedOptions event,
    Emitter<ElectrumSettingsState> emit,
  ) {
    final mainnetNetwork =
        state.isSelectedNetworkLiquid
            ? Network.liquidMainnet
            : Network.bitcoinMainnet;
    final testnetNetwork =
        state.isSelectedNetworkLiquid
            ? Network.liquidTestnet
            : Network.bitcoinTestnet;

    final List<ElectrumServer> updatedStagedServers = List<ElectrumServer>.from(
      state.stagedServers,
    );

    _updateServerAdvancedOptions(
      updatedStagedServers,
      mainnetNetwork,
      event.stopGap,
      event.retry,
      event.timeout,
    );

    _updateServerAdvancedOptions(
      updatedStagedServers,
      testnetNetwork,
      event.stopGap,
      event.retry,
      event.timeout,
    );

    emit(state.copyWith(stagedServers: updatedStagedServers));
  }

  void _updateServerAdvancedOptions(
    List<ElectrumServer> stagedServers,
    Network network,
    int? stopGap,
    int? retry,
    int? timeout,
  ) {
    final stagedIndex = stagedServers.indexWhere((server) {
      if (state.selectedProvider is CustomElectrumServerProvider) {
        return server.network == network &&
            server.electrumServerProvider is CustomElectrumServerProvider;
      } else {
        return server.network == network &&
            server.electrumServerProvider is DefaultServerProvider &&
            (server.electrumServerProvider as DefaultServerProvider)
                    .defaultServerProvider ==
                (state.selectedProvider as DefaultServerProvider)
                    .defaultServerProvider;
      }
    });

    if (stagedIndex >= 0) {
      stagedServers[stagedIndex] = stagedServers[stagedIndex].copyWith(
        stopGap: stopGap ?? 20,
        retry: retry ?? 5,
        timeout: timeout ?? 5,
      );
    } else {
      final existingServer = state.getServerForNetworkAndProvider(
        network,
        state.selectedProvider,
      );
      if (existingServer != null) {
        stagedServers.add(
          existingServer.copyWith(
            stopGap: stopGap ?? 20,
            retry: retry ?? 5,
            timeout: timeout ?? 5,
          ),
        );
      } else {
        if (state.selectedProvider is CustomElectrumServerProvider) {
          stagedServers.add(
            ElectrumServer(
              url: "", // Empty URL for custom server
              network: network,
              validateDomain: state.getValidateDomainForProvider(
                state.selectedProvider,
              ),
              stopGap: stopGap ?? 20,
              retry: retry ?? 5,
              timeout: timeout ?? 5,
            ),
          );
        } else if (state.selectedProvider is DefaultServerProvider) {
          final provider = state.selectedProvider as DefaultServerProvider;
          final url =
              provider.defaultServerProvider ==
                      DefaultElectrumServerProvider.blockstream
                  ? "blockstream.info"
                  : "bull.bitcoin.com";

          stagedServers.add(
            ElectrumServer(
              url: url,
              network: network,
              validateDomain: state.getValidateDomainForProvider(
                state.selectedProvider,
              ),
              stopGap: stopGap ?? 20,
              retry: retry ?? 5,
              timeout: timeout ?? 5,
            ),
          );
        }
      }
    }
  }

  Future<void> _onToggleDomainValidation(
    ToggleValidateDomain event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    final currentValidation = state.getValidateDomainForProvider(
      state.selectedProvider,
    );
    final newValidation = !currentValidation;

    final relevantServers =
        state.effectiveServers.where((server) {
          if (state.selectedProvider is CustomElectrumServerProvider) {
            return server.electrumServerProvider
                    is CustomElectrumServerProvider &&
                _isSameNetworkType(server.network, state.selectedNetwork);
          } else {
            return server.electrumServerProvider is DefaultServerProvider &&
                (server.electrumServerProvider as DefaultServerProvider)
                        .defaultServerProvider ==
                    (state.selectedProvider as DefaultServerProvider)
                        .defaultServerProvider &&
                _isSameNetworkType(server.network, state.selectedNetwork);
          }
        }).toList();

    final List<ElectrumServer> updatedStagedServers = List<ElectrumServer>.from(
      state.stagedServers,
    );

    for (final server in relevantServers) {
      final int stagedIndex = updatedStagedServers.indexWhere(
        (s) =>
            s.network == server.network &&
            _areProvidersEqual(
              s.electrumServerProvider,
              server.electrumServerProvider,
            ),
      );
      if (stagedIndex >= 0) {
        updatedStagedServers[stagedIndex] = updatedStagedServers[stagedIndex]
            .copyWith(validateDomain: newValidation);
      } else {
        updatedStagedServers.add(
          server.copyWith(validateDomain: newValidation),
        );
      }
    }

    if (updatedStagedServers.isEmpty || relevantServers.isEmpty) {
      final mainnetNetwork =
          state.isSelectedNetworkLiquid
              ? Network.liquidMainnet
              : Network.bitcoinMainnet;
      final testnetNetwork =
          state.isSelectedNetworkLiquid
              ? Network.liquidTestnet
              : Network.bitcoinTestnet;

      if (state.selectedProvider is CustomElectrumServerProvider) {
        updatedStagedServers.add(
          ElectrumServer(
            url: "",
            network: mainnetNetwork,
            validateDomain: newValidation,
          ),
        );
        updatedStagedServers.add(
          ElectrumServer(
            url: "",
            network: testnetNetwork,
            validateDomain: newValidation,
          ),
        );
      } else if (state.selectedProvider is DefaultServerProvider) {
        final provider = state.selectedProvider as DefaultServerProvider;
        final url =
            provider.defaultServerProvider ==
                    DefaultElectrumServerProvider.blockstream
                ? "blockstream.info"
                : "bull.bitcoin.com";

        updatedStagedServers.add(
          ElectrumServer(
            url: url,
            network: mainnetNetwork,
            validateDomain: newValidation,
          ),
        );
        updatedStagedServers.add(
          ElectrumServer(
            url: url,
            network: testnetNetwork,
            validateDomain: newValidation,
          ),
        );
      }
    }

    emit(state.copyWith(stagedServers: updatedStagedServers));
  }

  Future<void> _onSaveElectrumServerChanges(
    SaveElectrumServerChanges event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    try {
      emit(
        state.copyWith(status: ElectrumSettingsStatus.loading, statusError: ''),
      );

      final originalServers = List<ElectrumServer>.from(state.electrumServers);
      var stagedServers = List<ElectrumServer>.from(state.stagedServers);

      stagedServers = _updateServerActiveState(stagedServers);

      bool allSaved = true;

      for (final stagedServer in stagedServers) {
        final bool shouldSave =
            stagedServer.electrumServerProvider is DefaultServerProvider ||
            (stagedServer.electrumServerProvider
                    is CustomElectrumServerProvider &&
                (stagedServer.url.isNotEmpty));

        if (shouldSave) {
          bool success;

          // Get previous URL from our state map
          final serverKey = "custom_${stagedServer.network.name}";
          final previousUrl = state.previousUrls[serverKey];
          log.info(
            'Previous URL for ${stagedServer.network.name}: $previousUrl, stagedServer.url: ${stagedServer.url}',
          );
          // Use update method if previousUrl is available
          if (stagedServer.electrumServerProvider
                  is CustomElectrumServerProvider &&
              previousUrl != null &&
              _isSavedToDb(previousUrl)) {
            success = await _updateElectrumServerSettings.execute(
              electrumServer: stagedServer,
            );
          } else {
            success = await _storeElectrumServerSettings.execute(
              electrumServer: stagedServer,
            );
          }

          if (!success) allSaved = false;
          _updateInMemoryServer(originalServers, stagedServer);
        }
      }

      emit(
        state.copyWith(
          status:
              allSaved
                  ? ElectrumSettingsStatus.success
                  : ElectrumSettingsStatus.error,
          electrumServers: allSaved ? originalServers : state.electrumServers,
          stagedServers: allSaved ? [] : state.stagedServers,
          previousUrls: allSaved ? {} : state.previousUrls,
          saveSuccessful: allSaved,
          statusError: allSaved ? '' : 'Failed to save server changes',
        ),
      );
    } catch (e) {
      log.severe('Error saving server changes: $e');
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'Failed to save server changes',
        ),
      );
    }
  }

  List<ElectrumServer> _updateServerActiveState(List<ElectrumServer> servers) {
    final isSelectingDefault = state.selectedProvider is DefaultServerProvider;
    return servers.map((server) {
      final provider = server.electrumServerProvider;
      if (provider is DefaultServerProvider) {
        return server.copyWith(isActive: isSelectingDefault);
      } else {
        return server.copyWith(isActive: !isSelectingDefault);
      }
    }).toList();
  }

  void _onToggleCustomServerActive(
    ToggleCustomServerActive event,
    Emitter<ElectrumSettingsState> emit,
  ) {
    if (state.selectedProvider is! CustomElectrumServerProvider) return;

    final List<ElectrumServer> updatedStagedServers = List<ElectrumServer>.from(
      state.stagedServers,
    );

    final int stagedIndex = updatedStagedServers.indexWhere(
      (server) =>
          server.network == event.network &&
          server.electrumServerProvider is CustomElectrumServerProvider,
    );

    if (stagedIndex >= 0) {
      updatedStagedServers[stagedIndex] = updatedStagedServers[stagedIndex]
          .copyWith(isActive: event.isActive);
    } else {
      final existingServer = state.getServerForNetworkAndProvider(
        event.network,
        const ElectrumServerProvider.customProvider(),
      );
      if (existingServer != null) {
        updatedStagedServers.add(
          existingServer.copyWith(isActive: event.isActive),
        );
      } else {
        updatedStagedServers.add(
          ElectrumServer(
            url: "",
            network: event.network,
            isActive: event.isActive,
          ),
        );
      }
    }

    emit(state.copyWith(stagedServers: updatedStagedServers));
  }

  void _onToggleDefaultServerProvider(
    ToggleDefaultServerProvider event,
    Emitter<ElectrumSettingsState> emit,
  ) {
    final provider = ElectrumServerProvider.defaultProvider(
      defaultServerProvider: event.preset,
    );

    emit(state.copyWith(selectedProvider: provider));

    add(ToggleSelectedProvider(provider));
  }

  void _onToggleCustomServer(
    ToggleCustomServer event,
    Emitter<ElectrumSettingsState> emit,
  ) {
    final provider =
        event.isCustomSelected
            ? const ElectrumServerProvider.customProvider()
            : const ElectrumServerProvider.defaultProvider();

    final stagedServersList = List<ElectrumServer>.from(state.stagedServers);
    final updatedElectrumServers = List<ElectrumServer>.from(
      state.electrumServers,
    );

    if (!event.isCustomSelected) {
      final customServers =
          state.electrumServers
              .where(
                (server) =>
                    server.electrumServerProvider
                        is CustomElectrumServerProvider &&
                    _isSameNetworkType(server.network, state.selectedNetwork),
              )
              .toList();

      for (final server in customServers) {
        final index = updatedElectrumServers.indexOf(server);
        if (index >= 0) {
          updatedElectrumServers[index] = server.copyWith(isActive: false);

          final existingIndex = stagedServersList.indexWhere(
            (s) =>
                s.network == server.network &&
                s.electrumServerProvider is CustomElectrumServerProvider,
          );

          if (existingIndex >= 0) {
            stagedServersList[existingIndex] = stagedServersList[existingIndex]
                .copyWith(isActive: false);
          } else {
            stagedServersList.add(server.copyWith(isActive: false));
          }
        }
      }
    } else {
      final existingCustomServers =
          state.electrumServers
              .where(
                (server) =>
                    server.electrumServerProvider
                        is CustomElectrumServerProvider &&
                    _isSameNetworkType(server.network, state.selectedNetwork) &&
                    server.url.isNotEmpty,
              )
              .toList();

      if (existingCustomServers.isNotEmpty) {
        for (final server in existingCustomServers) {
          final existingIndex = stagedServersList.indexWhere(
            (s) =>
                s.network == server.network &&
                s.electrumServerProvider is CustomElectrumServerProvider,
          );

          if (existingIndex >= 0) {
            stagedServersList[existingIndex] = stagedServersList[existingIndex]
                .copyWith(isActive: true);
          } else {
            stagedServersList.add(server.copyWith(isActive: true));
          }
        }
      }
    }

    if (stagedServersList.isEmpty &&
        event.isCustomSelected != state.isCustomServerSelected) {
      final mainnetNetwork =
          state.isSelectedNetworkLiquid
              ? Network.liquidMainnet
              : Network.bitcoinMainnet;

      final existingServer = state.getServerForNetworkAndProvider(
        mainnetNetwork,
        event.isCustomSelected
            ? const ElectrumServerProvider.customProvider()
            : const ElectrumServerProvider.defaultProvider(),
      );

      if (existingServer != null) {
        stagedServersList.add(
          existingServer.copyWith(
            isActive: !event.isCustomSelected || existingServer.url.isNotEmpty,
          ),
        );
      } else if (!event.isCustomSelected) {
        stagedServersList.add(
          ElectrumServer(url: "", network: mainnetNetwork, isActive: true),
        );
      }
    }

    final prioritizedStagedServers = _updateServerActiveState(
      stagedServersList,
    );

    emit(
      state.copyWith(
        selectedProvider: provider,
        stagedServers: prioritizedStagedServers,
        electrumServers: updatedElectrumServers,
      ),
    );

    add(ToggleSelectedProvider(provider));
  }

  void _updateInMemoryServer(
    List<ElectrumServer> servers,
    ElectrumServer updatedServer,
  ) {
    final index = servers.indexWhere(
      (server) => _isSameServer(server, updatedServer),
    );
    if (index >= 0) {
      servers[index] = updatedServer;
    } else {
      servers.add(updatedServer);
    }
  }

  Future<ElectrumServerStatus> _checkElectrumServerStatus(
    ElectrumServer electrumServer,
  ) async {
    if (electrumServer.url.isNotEmpty) {
      try {
        return await _checkElectrumServerConnectivity.execute(
          url: electrumServer.url,
          timeout: 1,
        );
      } catch (e) {
        log.severe('Error checking server status: $e');
        return ElectrumServerStatus.offline;
      }
    }
    return ElectrumServerStatus.offline;
  }

  bool _isSavedToDb(String url) {
    if (url.trim().isEmpty) return false;

    // Normalize URL for comparison - trim and lower case
    final normalizedUrl = url.trim().toLowerCase();

    // For other URLs, check for exact match
    for (final server in state.electrumServers) {
      if (server.url.trim().toLowerCase() == normalizedUrl) {
        return true;
      }
    }

    return false;
  }

  bool _isSameNetworkType(Network network1, Network network2) {
    return network1.isBitcoin == network2.isBitcoin &&
        network1.isLiquid == network2.isLiquid;
  }

  bool _isSameServer(ElectrumServer a, ElectrumServer b) {
    if (!_isSameNetworkType(a.network, b.network)) return false;

    final aProvider = a.electrumServerProvider;
    final bProvider = b.electrumServerProvider;

    if (aProvider is CustomElectrumServerProvider &&
        bProvider is CustomElectrumServerProvider) {
      return a.url == b.url;
    }

    if (aProvider is DefaultServerProvider &&
        bProvider is DefaultServerProvider) {
      return aProvider.defaultServerProvider == bProvider.defaultServerProvider;
    }

    return false;
  }

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

  Future<void> _onSetPrimaryServer(
    SetPrimaryServer event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    try {
      final allServers = List<ElectrumServer>.from(state.electrumServers);

      // Update all servers with isActive = false
      for (var i = 0; i < allServers.length; i++) {
        if (allServers[i].network == event.server.network) {
          allServers[i] = allServers[i].copyWith(isActive: false);
        }
      }

      // Set the successful server as active
      final index = allServers.indexWhere(
        (s) => _isSameServer(s, event.server),
      );
      if (index >= 0) {
        allServers[index] = event.server.copyWith(
          isActive: true,
          status: ElectrumServerStatus.online,
        );

        // Update the provider to match this server's provider
        emit(
          state.copyWith(
            electrumServers: allServers,
            selectedProvider: event.server.electrumServerProvider,
          ),
        );

        // Save changes to persist the new primary server
        add(const SaveElectrumServerChanges());
      }
    } catch (e) {
      log.warning('Error setting primary server: $e');
    }
  }

  Future<void> _onReorderServers(
    ReorderServers event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    try {
      // Get current servers for the network
      final serversForNetwork =
          state.electrumServers
              .where((s) => s.network == event.network)
              .toList();

      if (event.oldIndex < event.newIndex) {
        // Moving down
        final newIndex = event.newIndex - 1;
        final server = serversForNetwork.removeAt(event.oldIndex);
        serversForNetwork.insert(newIndex, server);
      } else {
        // Moving up
        final server = serversForNetwork.removeAt(event.oldIndex);
        serversForNetwork.insert(event.newIndex, server);
      }

      // Update priorities based on new order
      final updatedServersForNetwork = <ElectrumServer>[];
      for (var i = 0; i < serversForNetwork.length; i++) {
        final server = serversForNetwork[i];
        final updatedServer = server.copyWith(
          priority: serversForNetwork.length - i,
        );
        updatedServersForNetwork.add(updatedServer);

        await _updateElectrumServerSettings.execute(
          electrumServer: updatedServer,
        );
      }

      final allServers = List<ElectrumServer>.from(state.electrumServers);
      for (final updatedServer in updatedServersForNetwork) {
        final index = allServers.indexWhere(
          (s) => _isSameServer(s, updatedServer),
        );
        if (index >= 0) {
          allServers[index] = updatedServer;
        }
      }

      emit(
        state.copyWith(
          electrumServers: allServers,
          status: ElectrumSettingsStatus.success,
        ),
      );
    } catch (e) {
      log.warning('Error reordering servers: $e');
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'Failed to update server priorities',
        ),
      );
    }
  }

  Future<void> _onDeleteCustomServer(
    DeleteCustomServer event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    try {
      final deleted = await _deleteElectrumServer.execute(
        url: event.server.url,
      );

      if (!deleted) {
        emit(
          state.copyWith(
            status: ElectrumSettingsStatus.error,
            statusError: 'Failed to delete server',
          ),
        );
        return;
      }

      final allServers = List<ElectrumServer>.from(state.electrumServers);
      allServers.removeWhere((s) => s.url == event.server.url);

      emit(
        state.copyWith(
          electrumServers: allServers,
          status: ElectrumSettingsStatus.success,
        ),
      );
    } catch (e) {
      log.warning('Error deleting server: $e');
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'Failed to delete server',
        ),
      );
    }
  }
}
