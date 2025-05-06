import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/check_electrum_server_connectivity_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_all_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_prioritized_server_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/update_electrum_server_settings_usecase.dart';
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
  final UpdateElectrumServerSettingsUsecase _updateElectrumServerSettings;
  final GetPrioritizedServerUsecase _getPrioritizedServerUsecase;
  final CheckElectrumServerConnectivityUsecase _checkElectrumServerConnectivity;

  ElectrumSettingsBloc({
    required GetAllElectrumServersUsecase getAllElectrumServers,
    required UpdateElectrumServerSettingsUsecase updateElectrumServerSettings,
    required GetPrioritizedServerUsecase getPrioritizedServerUsecase,
    required CheckElectrumServerConnectivityUsecase
    checkElectrumServerConnectivity,
  }) : _getAllElectrumServers = getAllElectrumServers,
       _updateElectrumServerSettings = updateElectrumServerSettings,
       _getPrioritizedServerUsecase = getPrioritizedServerUsecase,
       _checkElectrumServerConnectivity = checkElectrumServerConnectivity,
       super(const ElectrumSettingsState()) {
    on<LoadServers>(_onLoadServers);
    on<CheckServerStatus>(_onCheckServerStatus);
    on<ConfigureLiquidSettings>(_onConfigureLiquidSettings);
    on<ConfigureBitcoinSettings>(_onConfigureBitcoinSettings);
    on<ElectrumServerProviderChanged>(_onElectrumServerProviderChanged);
    on<UpdateCustomServerMainnet>(_onUpdateCustomServerMainnet);
    on<UpdateCustomServerTestnet>(_onUpdateCustomServerTestnet);
    on<UpdateElectrumAdvancedOptions>(_onUpdateElectrumAdvancedOptions);
    on<ToggleSelectedProvider>(_onToggleSelectedProvider);
    on<ToggleValidateDomain>(_onToggleDomainValidation);
    on<SetupBlockchain>(_onSetupBlockchain);
    on<SaveElectrumServerChanges>(_onSaveElectrumServerChanges);
    on<ToggleCustomServerActive>(_onToggleCustomServerActive);
    on<ToggleDefaultServerProvider>(_onToggleDefaultServerProvider);
    on<ToggleCustomServer>(_onToggleCustomServer);
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
        ),
      );
      debugPrint(
        "Prioritized server: ${prioritizedServer.electrumServerProvider}",
      );
      add(ToggleSelectedProvider(prioritizedServer.electrumServerProvider));
    } catch (e) {
      debugPrint('Error loading servers: $e');
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

      // Only check servers for the specific network
      final serversToCheck =
          state.electrumServers
              .where((s) => s.network == event.network)
              .toList();

      if (serversToCheck.isEmpty) {
        emit(state.copyWith(status: ElectrumSettingsStatus.success));
        return;
      }

      // Use microtask to offload connectivity checks from main thread
      await Future.microtask(() async {
        for (final server in serversToCheck) {
          final serverStatus = await _checkElectrumServerStatus(server);

          if (!emit.isDone) {
            emit(
              state.copyWith(
                status: ElectrumSettingsStatus.success,
                electrumServers:
                    state.electrumServers.map((s) {
                      if (_isSameServer(s, server)) {
                        return s.copyWith(status: serverStatus);
                      }
                      return s;
                    }).toList(),
              ),
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Error checking server status: $e');
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

  //todo(stax); check if this can be removed
  void _onElectrumServerProviderChanged(
    ElectrumServerProviderChanged event,
    Emitter<ElectrumSettingsState> emit,
  ) {
    emit(state.copyWith(selectedProvider: event.type));
  }

  Future<void> _onToggleSelectedProvider(
    ToggleSelectedProvider event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    debugPrint('Toggling selected provider: ${event.provider}');
    emit(state.copyWith(status: ElectrumSettingsStatus.loading));

    emit(
      state.copyWith(
        selectedProvider: event.provider,
        status: ElectrumSettingsStatus.loading,
      ),
    );

    // Create a copy of electrum servers to update their status
    final updatedElectrumServers = List<ElectrumServer>.from(
      state.electrumServers,
    );

    // Get the mainnet network for the current selected type (Bitcoin or Liquid)
    final mainnetNetwork =
        state.isSelectedNetworkLiquid
            ? Network.liquidMainnet
            : Network.bitcoinMainnet;

    // Find server for selected provider and mainnet (most important server)
    final mainnetServer = state.getServerForNetworkAndProvider(
      mainnetNetwork,
      event.provider,
    );

    // Check connectivity for the selected provider's server if it exists
    if (mainnetServer != null && mainnetServer.url.isNotEmpty) {
      try {
        // Start asynchronous connectivity check without blocking the UI
        await Future.microtask(() async {
          final status = await _checkElectrumServerStatus(mainnetServer);

          // Find and update the server in our list
          final index = updatedElectrumServers.indexWhere(
            (s) => _isSameServer(s, mainnetServer),
          );

          if (index >= 0 && !emit.isDone) {
            updatedElectrumServers[index] = updatedElectrumServers[index]
                .copyWith(status: status);

            // Update the state with the server's new status
            emit(
              state.copyWith(
                electrumServers: updatedElectrumServers,
                status: ElectrumSettingsStatus.success,
              ),
            );
          }
        });
      } catch (e) {
        debugPrint('Error checking server connectivity: $e');
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
          ElectrumServer.customServer(
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
          ElectrumServer.customServer(
            network: testnetNetwork,
            validateDomain: false,
          ),
        );
      }

      if (updatedStagedServers.length > state.stagedServers.length) {
        emit(
          state.copyWith(
            stagedServers: updatedStagedServers,
            status: ElectrumSettingsStatus.loading,
          ),
        );
      }
    } else if (event.provider is DefaultServerProvider) {
      // For default providers, also check connectivity for both configured providers
      // but do it in the background to prevent UI freezing
      final defaultProvider =
          (event.provider as DefaultServerProvider).defaultServerProvider;

      await Future.microtask(() async {
        // Find all servers with this provider
        final serversToCheck =
            state.electrumServers.where((s) {
              if (s.electrumServerProvider is DefaultServerProvider) {
                return (s.electrumServerProvider as DefaultServerProvider)
                            .defaultServerProvider ==
                        defaultProvider &&
                    _isSameNetworkType(s.network, state.selectedNetwork);
              }
              return false;
            }).toList();

        for (final server in serversToCheck) {
          if (server.url.isNotEmpty) {
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

    final List<ElectrumServer> updatedStagedServers = List<ElectrumServer>.from(
      state.stagedServers,
    );

    // Allow users to input URL without protocol prefix
    final customServer = event.customServer.trim();

    final network =
        state.isSelectedNetworkLiquid
            ? Network.liquidMainnet
            : Network.bitcoinMainnet;

    // Check if this URL already exists in electrumServers but for a different network
    final urlExists = _urlExists(customServer);
    if (urlExists) {
      // Emit a state with error to show in UI
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'This URL is already in use for another network',
        ),
      );

      return;
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
      debugPrint('Updating custom server');
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
          ElectrumServer.customServer(
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
        status: ElectrumSettingsStatus.success,
      ),
    );
  }

  Future<void> _onUpdateCustomServerTestnet(
    UpdateCustomServerTestnet event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    if (state.selectedProvider is! CustomElectrumServerProvider) return;

    final List<ElectrumServer> updatedStagedServers = List<ElectrumServer>.from(
      state.stagedServers,
    );

    // Allow users to input URL without protocol prefix
    final customServer = event.customServer.trim();

    final network =
        state.isSelectedNetworkLiquid
            ? Network.liquidTestnet
            : Network.bitcoinTestnet;

    // Check if this URL already exists in electrumServers but for a different network
    final urlExists = _urlExists(customServer);
    if (urlExists) {
      // Emit a state with error to show in UI
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'This URL is already in use for another network',
        ),
      );

      return;
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
          ElectrumServer.customServer(
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
            ElectrumServer.customServer(
              network: network,
              validateDomain: state.getValidateDomainForProvider(
                state.selectedProvider,
              ),
              stopGap: stopGap ?? 20,
              retry: retry ?? 5,
              timeout: timeout ?? 5,
            ),
          );
        } else {
          stagedServers.add(
            ElectrumServer.defaultServer(
              provider:
                  (state.selectedProvider as DefaultServerProvider)
                      .defaultServerProvider,
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

  Future<void> _onSetupBlockchain(
    SetupBlockchain event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    try {
      emit(state.copyWith(status: ElectrumSettingsStatus.loading));

      await Future.delayed(const Duration(seconds: 1));

      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.success,
          saveSuccessful: true,
        ),
      );
    } catch (e) {
      debugPrint('Error setting up blockchain: $e');
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'Failed to set up blockchain',
        ),
      );
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
      if (state.selectedProvider is CustomElectrumServerProvider) {
        updatedStagedServers.add(
          ElectrumServer.customServer(
            network: mainnetNetwork,
            validateDomain: newValidation,
          ),
        );
      } else {
        updatedStagedServers.add(
          ElectrumServer.defaultServer(
            provider:
                (state.selectedProvider as DefaultServerProvider)
                    .defaultServerProvider,
            network: mainnetNetwork,
            validateDomain: newValidation,
          ),
        );
      }

      final testnetNetwork =
          state.isSelectedNetworkLiquid
              ? Network.liquidTestnet
              : Network.bitcoinTestnet;
      if (state.selectedProvider is CustomElectrumServerProvider) {
        updatedStagedServers.add(
          ElectrumServer.customServer(
            network: testnetNetwork,
            validateDomain: newValidation,
          ),
        );
      } else {
        updatedStagedServers.add(
          ElectrumServer.defaultServer(
            provider:
                (state.selectedProvider as DefaultServerProvider)
                    .defaultServerProvider,
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
    debugPrint('Saving Electrum server changes...');
    debugPrint('Staged servers: ${state.stagedServers}');
    try {
      emit(state.copyWith(status: ElectrumSettingsStatus.loading));

      final originalServers = List<ElectrumServer>.from(state.electrumServers);
      var stagedServers = List<ElectrumServer>.from(state.stagedServers);

      // Filter out custom servers without URLs - they should not be saved
      stagedServers =
          stagedServers.where((server) {
            if (server.electrumServerProvider is CustomElectrumServerProvider) {
              return server.url.isNotEmpty;
            }
            return true;
          }).toList();

      stagedServers = _updateServerPriorities(stagedServers);

      if (state.isCustomServerSelected) {
        // We'll check connectivity for each active custom server before saving
        for (final server in stagedServers.where(
          (s) => s.electrumServerProvider is CustomElectrumServerProvider,
        )) {
          // Validate URL
          if (server.url.isEmpty) {
            emit(
              state.copyWith(
                status: ElectrumSettingsStatus.error,
                statusError: 'URL cannot be empty for ${server.network.name}',
              ),
            );
            return;
          }

          // Check connectivity for each server
          try {
            final serverStatus = await _checkElectrumServerConnectivity.execute(
              url: server.url,
              timeout: server.timeout,
            );

            if (serverStatus == ElectrumServerStatus.offline) {
              debugPrint(
                'Server ${server.url} is offline. Cannot save changes.',
              );
              emit(
                state.copyWith(
                  status: ElectrumSettingsStatus.error,
                  statusError:
                      'Cannot connect to ${server.url}. Please check the URL.',
                ),
              );
              return;
            }
          } catch (e) {
            debugPrint(
              'Error checking server connectivity for ${server.url}: $e',
            );
            // We'll continue anyway, since the user might be offline or the server might be temporary down
          }
        }
      }

      bool allSaved = true;

      for (final stagedServer in stagedServers) {
        final bool shouldSave =
            stagedServer.electrumServerProvider is DefaultServerProvider ||
            (stagedServer.electrumServerProvider
                    is CustomElectrumServerProvider &&
                (stagedServer.url.isNotEmpty || !stagedServer.isActive));

        if (shouldSave) {
          final success = await _updateElectrumServerSettings.execute(
            electrumServer: stagedServer,
          );

          if (!success) {
            allSaved = false;
            debugPrint('Failed to save server: ${stagedServer.url}');
          }
          _updateInMemoryServer(originalServers, stagedServer);
        }
      }

      if (allSaved) {
        final networksToCheck =
            stagedServers.map((s) => s.network).toSet().toList();
        for (final network in networksToCheck) {
          final updatedServers = await _getAllElectrumServers.execute(
            network: network,
          );
          for (final updated in updatedServers) {
            _updateInMemoryServer(originalServers, updated);
          }
        }
      }

      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.success,
          electrumServers: originalServers,
          stagedServers: [],
          saveSuccessful: allSaved,
        ),
      );
    } catch (e) {
      debugPrint('Error saving server changes: $e');
      emit(
        state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'Failed to save server changes',
        ),
      );
    }
  }

  List<ElectrumServer> _updateServerPriorities(List<ElectrumServer> servers) {
    return servers.map((server) {
      if (server.electrumServerProvider is DefaultServerProvider) {
        final defaultProvider =
            (server.electrumServerProvider as DefaultServerProvider)
                .defaultServerProvider;

        return server.copyWith(
          priority: switch (defaultProvider) {
            DefaultElectrumServerProvider.bullBitcoin => 1,
            DefaultElectrumServerProvider.blockstream => 2,
          },
        );
      } else if (server.electrumServerProvider
          is CustomElectrumServerProvider) {
        // Only activate custom servers if they have a URL
        return server.copyWith(
          isActive: server.url.isNotEmpty,
          priority: server.url.isNotEmpty ? 0 : 99,
        );
      }
      return server;
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
          ElectrumServer.customServer(
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

    // Create a copy of the current stagedServers
    final stagedServersList = List<ElectrumServer>.from(state.stagedServers);

    // Update electrumServers to mark custom servers inactive when switching to default
    final updatedElectrumServers = List<ElectrumServer>.from(
      state.electrumServers,
    );

    // Only affect custom servers for the currently selected network (Bitcoin or Liquid)
    if (!event.isCustomSelected) {
      // Find all the custom servers for the current network type only (Bitcoin or Liquid)
      final customServers =
          state.electrumServers
              .where(
                (server) =>
                    server.electrumServerProvider
                        is CustomElectrumServerProvider &&
                    _isSameNetworkType(server.network, state.selectedNetwork),
              )
              .toList();

      // When switching to default, mark the servers for current network type as inactive
      for (final server in customServers) {
        final index = updatedElectrumServers.indexOf(server);
        if (index >= 0) {
          updatedElectrumServers[index] = server.copyWith(
            isActive: false,
            priority: 99,
          );

          // Add to staged servers to ensure the change is saved
          final existingIndex = stagedServersList.indexWhere(
            (s) =>
                s.network == server.network &&
                s.electrumServerProvider is CustomElectrumServerProvider,
          );

          if (existingIndex >= 0) {
            stagedServersList[existingIndex] = stagedServersList[existingIndex]
                .copyWith(isActive: false, priority: 99);
          } else {
            stagedServersList.add(
              server.copyWith(isActive: false, priority: 99),
            );
          }
        }
      }
    } else {
      // Find existing custom servers with URLs for the current selected network type only
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

      // When switching to custom, activate the servers for current network type
      if (existingCustomServers.isNotEmpty) {
        for (final server in existingCustomServers) {
          final existingIndex = stagedServersList.indexWhere(
            (s) =>
                s.network == server.network &&
                s.electrumServerProvider is CustomElectrumServerProvider,
          );

          if (existingIndex >= 0) {
            stagedServersList[existingIndex] = stagedServersList[existingIndex]
                .copyWith(isActive: true, priority: 0);
          } else {
            stagedServersList.add(server.copyWith(isActive: true, priority: 0));
          }
        }
      }
    }

    // If no staged changes but we're switching modes, add a marker to make save button active
    if (stagedServersList.isEmpty &&
        event.isCustomSelected != state.isCustomServerSelected) {
      // Use the mainnet server of the currently selected network type
      final mainnetNetwork =
          state.isSelectedNetworkLiquid
              ? Network.liquidMainnet
              : Network.bitcoinMainnet;

      // Find existing server for this network
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
          ElectrumServer.defaultServer(
            provider: DefaultElectrumServerProvider.bullBitcoin,
            network: mainnetNetwork,
          ),
        );
      }
    }

    // Apply updated priorities to the final list
    final prioritizedStagedServers = _updateServerPriorities(stagedServersList);

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
        final status = await _checkElectrumServerConnectivity.execute(
          url: electrumServer.url,
          timeout: electrumServer.timeout,
        );
        return status;
      } catch (e) {
        debugPrint('Error checking server status: $e');
        return ElectrumServerStatus.offline;
      }
    }
    return ElectrumServerStatus.offline;
  }

  bool _urlExists(String url) {
    if (url.isEmpty) return false;

    for (final server in state.electrumServers) {
      if (server.url == url.trim()) {
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
    if (a.network != b.network) return false;

    if (a.electrumServerProvider is CustomElectrumServerProvider &&
        b.electrumServerProvider is CustomElectrumServerProvider) {
      return a.url == b.url;
    }

    if (a.electrumServerProvider is DefaultServerProvider &&
        b.electrumServerProvider is DefaultServerProvider) {
      return (a.electrumServerProvider as DefaultServerProvider)
              .defaultServerProvider ==
          (b.electrumServerProvider as DefaultServerProvider)
              .defaultServerProvider;
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
}
