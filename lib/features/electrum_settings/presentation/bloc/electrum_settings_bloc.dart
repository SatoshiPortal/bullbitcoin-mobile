import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/check_electrum_status_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_all_electrum_servers_usecase.dart';
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

  ElectrumSettingsBloc({
    required GetAllElectrumServersUsecase getAllElectrumServers,
    required CheckElectrumStatusUsecase checkElectrumStatusUsecase,
  })  : _getAllElectrumServers = getAllElectrumServers,
        _checkElectrumStatus = checkElectrumStatusUsecase,
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
      await Future.delayed(const Duration(milliseconds: 200));
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
      Emitter<ElectrumSettingsState> emit) {}

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

  Future<void> _onSaveElectrumServerChanges(SaveElectrumServerChanges event,
      Emitter<ElectrumSettingsState> emit) async {
    try {
      emit(state.copyWith(status: ElectrumSettingsStatus.loading));

      final originalServers = List<ElectrumServer>.from(state.electrumServers);
      final stagedServers = state.stagedServers;

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

      // Apply staged changes to original servers
      for (final stagedServer in stagedServers) {
        final index = originalServers.indexWhere((server) =>
            server.network == stagedServer.network &&
            server.provider == stagedServer.provider);

        if (index >= 0) {
          originalServers[index] = stagedServer;
        } else {
          originalServers.add(stagedServer);
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));

      emit(state.copyWith(
        status: ElectrumSettingsStatus.success,
        electrumServers: originalServers,
        stagedServers: [], // Clear staged changes
        saveSuccessful: true,
      ));
    } catch (e) {
      debugPrint('Error saving server changes: $e');
      emit(state.copyWith(
        status: ElectrumSettingsStatus.error,
        statusError: 'Failed to save server changes',
      ));
    }
  }
}
