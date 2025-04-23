import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/check_electrum_status_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_all_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/update_electrum_server_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart' show Network;
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
  final CheckElectrumStatusUsecase _checkElectrumStatus;
  final UpdateElectrumServerSettingsUsecase _updateElectrumServerSettings;

  ElectrumSettingsBloc({
    required GetAllElectrumServersUsecase getAllElectrumServers,
    required CheckElectrumStatusUsecase checkElectrumStatusUsecase,
    required UpdateElectrumServerSettingsUsecase updateElectrumServerSettings,
  })  : _getAllElectrumServers = getAllElectrumServers,
        _checkElectrumStatus = checkElectrumStatusUsecase,
        _updateElectrumServerSettings = updateElectrumServerSettings,
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
  }

  Future<void> _onLoadServers(
      LoadServers event, Emitter<ElectrumSettingsState> emit) async {
    try {
      emit(state.copyWith(status: ElectrumSettingsStatus.loading));

      final List<ElectrumServer> allServers = [];
      final networks = state.isSelectedNetworkLiquid
          ? [Network.liquidMainnet, Network.liquidTestnet]
          : [Network.bitcoinMainnet, Network.bitcoinTestnet];

      for (final network in networks) {
        final servers = await _getAllElectrumServers.execute(
          checkStatus: true,
          network: network,
        );

        allServers.addAll(servers);
      }

      if (allServers.isEmpty) {
        emit(state.copyWith(
          status: ElectrumSettingsStatus.error,
          statusError: 'No servers available',
        ));
        return;
      }
      final currentProvider = _determineCurrentProvider(allServers);

      emit(state.copyWith(
        electrumServers: allServers,
        selectedProvider: currentProvider,
      ));
      add(ToggleSelectedProvider(currentProvider));
      emit(state.copyWith(status: ElectrumSettingsStatus.success));
    } catch (e) {
      debugPrint('Error loading servers: $e');
      emit(state.copyWith(
        status: ElectrumSettingsStatus.error,
        statusError: 'Failed to load servers',
      ));
    }
  }

  ElectrumServerProvider _determineCurrentProvider(
      List<ElectrumServer> servers) {
    if (servers.isEmpty) return ElectrumServerProvider.bullBitcoin;

    final mainServer = servers.firstWhere(
      (server) =>
          (state.isSelectedNetworkLiquid
              ? server.network.isLiquid
              : server.network.isBitcoin) &&
          !server.network.isTestnet,
      orElse: () => servers.first,
    );

    return mainServer.provider;
  }

  Future<void> _onCheckServerStatus(
      CheckServerStatus event, Emitter<ElectrumSettingsState> emit) async {
    try {
      emit(state.copyWith(status: ElectrumSettingsStatus.loading));

      final updatedServer = await _checkElectrumStatus.execute(
        provider: event.electrumServerProvider,
        network: event.network,
      );

      final updatedElectrumServers = state.electrumServers.map((server) {
        if (server.provider == event.electrumServerProvider &&
            server.network == event.network) {
          return updatedServer;
        }
        return server;
      }).toList();

      emit(state.copyWith(
        status: ElectrumSettingsStatus.success,
        electrumServers: updatedElectrumServers as List<ElectrumServer>,
      ));
    } catch (e) {
      debugPrint('Error checking server status: $e');
      emit(state.copyWith(
        status: ElectrumSettingsStatus.error,
        statusError: 'Failed to check server status',
      ));
    }
  }

  void _onConfigureLiquidSettings(
      ConfigureLiquidSettings event, Emitter<ElectrumSettingsState> emit) {
    emit(state.copyWith(
      status: ElectrumSettingsStatus.loading,
      selectedNetwork: Network.liquidMainnet,
    ));
    add(LoadServers());
  }

  void _onConfigureBitcoinSettings(
      ConfigureBitcoinSettings event, Emitter<ElectrumSettingsState> emit) {
    emit(state.copyWith(
      status: ElectrumSettingsStatus.loading,
      selectedNetwork: Network.bitcoinMainnet,
    ));
    add(LoadServers());
  }

  void _onElectrumServerProviderChanged(ElectrumServerProviderChanged event,
      Emitter<ElectrumSettingsState> emit) {
    emit(state.copyWith(selectedProvider: event.type));
  }

  Future<void> _onToggleSelectedProvider(
      ToggleSelectedProvider event, Emitter<ElectrumSettingsState> emit) async {
    // First emit a loading state to signal the UI to show progress
    emit(state.copyWith(status: ElectrumSettingsStatus.loading));

    // Set the selected provider
    emit(state.copyWith(
      selectedProvider: event.provider,
      // Keep status as loading
      status: ElectrumSettingsStatus.loading,
    ));

    // If switching to custom provider and there are no custom servers yet,
    // create placeholder servers in staged changes
    if (event.provider == ElectrumServerProvider.custom) {
      final List<ElectrumServer> updatedStagedServers =
          List<ElectrumServer>.from(state.stagedServers);

      // Check if we need to add a mainnet server
      final mainnetNetwork = state.isSelectedNetworkLiquid
          ? Network.liquidMainnet
          : Network.bitcoinMainnet;

      final hasMainnetServer = state.getServerForNetworkAndProvider(
            mainnetNetwork,
            event.provider,
          ) !=
          null;

      if (!hasMainnetServer) {
        updatedStagedServers.add(ElectrumServer(
          provider: event.provider,
          network: mainnetNetwork,
          url: '',
          validateDomain: false,
        ));
      }

      // Check if we need to add a testnet server
      final testnetNetwork = state.isSelectedNetworkLiquid
          ? Network.liquidTestnet
          : Network.bitcoinTestnet;

      final hasTestnetServer = state.getServerForNetworkAndProvider(
            testnetNetwork,
            event.provider,
          ) !=
          null;

      if (!hasTestnetServer) {
        updatedStagedServers.add(ElectrumServer(
          provider: event.provider,
          network: testnetNetwork,
          url: '',
          validateDomain: false,
        ));
      }

      if (updatedStagedServers.length > state.stagedServers.length) {
        emit(state.copyWith(
          stagedServers: updatedStagedServers,
          // Keep status as loading
          status: ElectrumSettingsStatus.loading,
        ));
      }
    }

    // Check if emit is still valid before calling it
    if (!emit.isDone) {
      // Complete the process by setting status to success
      emit(state.copyWith(status: ElectrumSettingsStatus.success));
    }
  }

  void _onUpdateCustomServerMainnet(
      UpdateCustomServerMainnet event, Emitter<ElectrumSettingsState> emit) {
    if (state.selectedProvider != ElectrumServerProvider.custom) return;

    final List<ElectrumServer> updatedStagedServers =
        List<ElectrumServer>.from(state.stagedServers);

    final network = state.isSelectedNetworkLiquid
        ? Network.liquidMainnet
        : Network.bitcoinMainnet;

    final int stagedIndex = updatedStagedServers.indexWhere((server) =>
        server.network == network && server.provider == state.selectedProvider);

    if (stagedIndex >= 0) {
      updatedStagedServers[stagedIndex] =
          updatedStagedServers[stagedIndex].copyWith(
        url: event.customServer,
      );
    } else {
      final existingServerIndex = state.electrumServers.indexWhere((server) =>
          server.network == network &&
          server.provider == state.selectedProvider);

      if (existingServerIndex >= 0) {
        updatedStagedServers.add(state.electrumServers[existingServerIndex]
            .copyWith(url: event.customServer));
      } else {
        updatedStagedServers.add(ElectrumServer(
          provider: state.selectedProvider,
          network: network,
          url: event.customServer,
          validateDomain:
              state.getValidateDomainForProvider(state.selectedProvider),
        ));
      }
    }

    emit(state.copyWith(stagedServers: updatedStagedServers));
  }

  void _onUpdateCustomServerTestnet(
      UpdateCustomServerTestnet event, Emitter<ElectrumSettingsState> emit) {
    if (state.selectedProvider != ElectrumServerProvider.custom) return;

    final List<ElectrumServer> updatedStagedServers =
        List<ElectrumServer>.from(state.stagedServers);

    final network = state.isSelectedNetworkLiquid
        ? Network.liquidTestnet
        : Network.bitcoinTestnet;

    final int stagedIndex = updatedStagedServers.indexWhere((server) =>
        server.network == network && server.provider == state.selectedProvider);

    if (stagedIndex >= 0) {
      updatedStagedServers[stagedIndex] =
          updatedStagedServers[stagedIndex].copyWith(
        url: event.customServer,
      );
    } else {
      final existingServerIndex = state.electrumServers.indexWhere((server) =>
          server.network == network &&
          server.provider == state.selectedProvider);

      if (existingServerIndex >= 0) {
        updatedStagedServers.add(state.electrumServers[existingServerIndex]
            .copyWith(url: event.customServer));
      } else {
        updatedStagedServers.add(ElectrumServer(
          provider: state.selectedProvider,
          network: network,
          url: event.customServer,
          validateDomain:
              state.getValidateDomainForProvider(state.selectedProvider),
        ));
      }
    }

    emit(state.copyWith(stagedServers: updatedStagedServers));
  }

  void _onUpdateElectrumAdvancedOptions(UpdateElectrumAdvancedOptions event,
      Emitter<ElectrumSettingsState> emit) {
    // Get the mainnet and testnet networks
    final mainnetNetwork = state.isSelectedNetworkLiquid
        ? Network.liquidMainnet
        : Network.bitcoinMainnet;

    final testnetNetwork = state.isSelectedNetworkLiquid
        ? Network.liquidTestnet
        : Network.bitcoinTestnet;

    // Create updated staged servers list
    final List<ElectrumServer> updatedStagedServers =
        List<ElectrumServer>.from(state.stagedServers);

    // Update or create mainnet server
    _updateServerAdvancedOptions(
      updatedStagedServers,
      mainnetNetwork,
      event.stopGap,
      event.retry,
      event.timeout,
    );

    // Update or create testnet server
    _updateServerAdvancedOptions(
      updatedStagedServers,
      testnetNetwork,
      event.stopGap,
      event.retry,
      event.timeout,
    );

    emit(state.copyWith(stagedServers: updatedStagedServers));
  }

  // Helper method to update server advanced options
  void _updateServerAdvancedOptions(
    List<ElectrumServer> stagedServers,
    Network network,
    int? stopGap,
    int? retry,
    int? timeout,
  ) {
    // Check if server exists in staged servers
    final stagedIndex = stagedServers.indexWhere((server) =>
        server.network == network && server.provider == state.selectedProvider);

    if (stagedIndex >= 0) {
      stagedServers[stagedIndex] = stagedServers[stagedIndex].copyWith(
        stopGap: stopGap ?? 20,
        retry: retry ?? 5,
        timeout: timeout ?? 5,
      );
    } else {
      // Check if server exists in original servers
      final existingServerIndex = state.electrumServers.indexWhere(
        (server) =>
            server.network == network &&
            server.provider == state.selectedProvider,
      );

      if (existingServerIndex >= 0) {
        // Use existing server as base and update only non-null values
        stagedServers.add(state.electrumServers[existingServerIndex].copyWith(
          stopGap: stopGap ?? 20,
          retry: retry ?? 5,
          timeout: timeout ?? 5,
        ));
      } else {
        stagedServers.add(ElectrumServer(
          provider: state.selectedProvider,
          network: network,
          url: '',
          validateDomain:
              state.getValidateDomainForProvider(state.selectedProvider),
          stopGap: stopGap ?? 20,
          retry: retry ?? 5,
          timeout: timeout ?? 5,
        ));
      }
    }
  }

  Future<void> _onSetupBlockchain(
      SetupBlockchain event, Emitter<ElectrumSettingsState> emit) async {
    try {
      emit(state.copyWith(status: ElectrumSettingsStatus.loading));

      await Future.delayed(const Duration(seconds: 1));

      emit(state.copyWith(
        status: ElectrumSettingsStatus.success,
        saveSuccessful: true,
      ));
    } catch (e) {
      debugPrint('Error setting up blockchain: $e');
      emit(state.copyWith(
        status: ElectrumSettingsStatus.error,
        statusError: 'Failed to set up blockchain',
      ));
    }
  }

  Future<void> _onToggleDomainValidation(
      ToggleValidateDomain event, Emitter<ElectrumSettingsState> emit) async {
    final currentValidation =
        state.getValidateDomainForProvider(state.selectedProvider);
    final newValidation = !currentValidation;

    // Only target servers matching both provider AND network type (bitcoin/liquid)
    final relevantServers = state.effectiveServers
        .where((server) =>
            server.provider == state.selectedProvider &&
            _isSameNetworkType(server.network, state.selectedNetwork))
        .toList();

    final List<ElectrumServer> updatedStagedServers =
        List<ElectrumServer>.from(state.stagedServers);

    for (final server in relevantServers) {
      final int stagedIndex = updatedStagedServers.indexWhere(
          (s) => s.network == server.network && s.provider == server.provider);

      if (stagedIndex >= 0) {
        updatedStagedServers[stagedIndex] =
            updatedStagedServers[stagedIndex].copyWith(
          validateDomain: newValidation,
        );
      } else {
        updatedStagedServers
            .add(server.copyWith(validateDomain: newValidation));
      }
    }

    // If no existing servers were found, create entries for both mainnet and testnet
    // of the current selected network type
    if (updatedStagedServers.isEmpty || relevantServers.isEmpty) {
      // Add for mainnet of current network type
      final mainnetNetwork = state.isSelectedNetworkLiquid
          ? Network.liquidMainnet
          : Network.bitcoinMainnet;

      updatedStagedServers.add(ElectrumServer(
        provider: state.selectedProvider,
        network: mainnetNetwork,
        url: '',
        validateDomain: newValidation,
      ));

      // Add for testnet of current network type
      final testnetNetwork = state.isSelectedNetworkLiquid
          ? Network.liquidTestnet
          : Network.bitcoinTestnet;

      updatedStagedServers.add(ElectrumServer(
        provider: state.selectedProvider,
        network: testnetNetwork,
        url: '',
        validateDomain: newValidation,
      ));
    }

    emit(state.copyWith(stagedServers: updatedStagedServers));
  }

  // Helper method to check if two networks are of the same type (Bitcoin/Liquid)
  // regardless of whether they're mainnet or testnet
  bool _isSameNetworkType(Network network1, Network network2) {
    return network1.isBitcoin == network2.isBitcoin &&
        network1.isLiquid == network2.isLiquid;
  }

  Future<void> _onSaveElectrumServerChanges(SaveElectrumServerChanges event,
      Emitter<ElectrumSettingsState> emit) async {
    try {
      emit(state.copyWith(status: ElectrumSettingsStatus.loading));

      final originalServers = List<ElectrumServer>.from(state.electrumServers);
      final stagedServers = state.stagedServers;

      // Track success/failure of save operations
      bool allSaved = true;

      // Validate URLs for custom servers before saving
      if (state.selectedProvider == ElectrumServerProvider.custom) {
        for (final server in stagedServers) {
          if (server.provider == ElectrumServerProvider.custom) {
            // Very basic URL validation
            if (server.url.isEmpty || !server.url.contains(':')) {
              emit(state.copyWith(
                status: ElectrumSettingsStatus.error,
                statusError: 'Invalid server URL format',
              ));
              return;
            }
          }
        }
      }

      // Save each staged server to storage using the usecase
      for (final stagedServer in stagedServers) {
        final success = await _updateElectrumServerSettings.execute(
          electrumServer: stagedServer,
        );

        // If any server fails to save, mark overall operation as failed
        if (!success) {
          allSaved = false;
          debugPrint('Failed to save server: ${stagedServer.url}');
        }

        // Update our in-memory model too
        final index = originalServers.indexWhere((server) =>
            server.network == stagedServer.network &&
            server.provider == stagedServer.provider);

        if (index >= 0) {
          originalServers[index] = stagedServer;
        } else {
          originalServers.add(stagedServer);
        }
      }

      emit(state.copyWith(
        status: allSaved
            ? ElectrumSettingsStatus.success
            : ElectrumSettingsStatus.error,
        statusError: allSaved ? '' : 'Some changes could not be saved',
        electrumServers: originalServers,
        stagedServers: [], // Clear staged changes
        saveSuccessful: allSaved,
      ));
    } catch (e) {
      debugPrint('Error saving server changes: $e');
      emit(state.copyWith(
        status: ElectrumSettingsStatus.error,
        statusError: 'Failed to save server changes: $e',
      ));
    }
  }
}
