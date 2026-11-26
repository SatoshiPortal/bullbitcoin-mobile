import '../domain/electrum_settings_failure.dart';
import '../domain/load_electrum_settings_usecase.dart';
import '../domain/add_electrum_server_usecase.dart';
import '../domain/prioritize_electrum_servers_usecase.dart';
import '../domain/remove_electrum_server_usecase.dart';
import '../domain/update_electrum_settings_usecase.dart';

import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

import 'electrum_advanced_options_view_model.dart';
import 'electrum_server_view_model.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_settings_bloc.freezed.dart';
part 'electrum_settings_event.dart';
part 'electrum_settings_state.dart';

class ElectrumSettingsBloc
    extends Bloc<ElectrumSettingsEvent, ElectrumSettingsState> {
  final LoadElectrumSettingsUsecase _loadSettings;
  final AddElectrumServerUsecase _addServer;
  final PrioritizeElectrumServersUsecase _prioritizeServers;
  final RemoveElectrumServerUsecase _removeServer;
  final UpdateElectrumSettingsUsecase _updateSettings;
  int _loadGeneration = 0;

  ElectrumSettingsBloc({
    required this._loadSettings,
    required this._addServer,
    required this._prioritizeServers,
    required this._removeServer,
    required this._updateSettings,
  }) : super(const ElectrumSettingsState()) {
    on<ElectrumSettingsLoaded>(_onLoaded);
    on<ElectrumCustomServerAdded>(_onCustomServerAdded);
    on<ElectrumCustomServersPrioritized>(_onCustomServersPrioritized);
    on<ElectrumCustomServerDeleted>(_onCustomServerDeleted);
    on<ElectrumAdvancedOptionsSaved>(_onAdvancedOptionsSaved);
    on<ElectrumAdvancedOptionsReset>(_onAdvancedOptionsReset);
  }

  Future<void> _onLoaded(
    ElectrumSettingsLoaded event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        isLiquid: event.isLiquid,
        environment: null,
        defaultServers: const [],
        customServers: const [],
        advancedOptions: null,
        isLoadingData: true,
        electrumServersError: null,
        advancedOptionsError: null,
      ),
    );

    final result = await _loadSettings.execute(
      isLiquid: event.isLiquid,
      isCurrent: () => generation == _loadGeneration && !emit.isDone,
      onUpdate: (response) {
        if (generation != _loadGeneration || emit.isDone) return;
        emit(_stateWithServerData(response, isLoadingData: true));
      },
    );
    if (generation != _loadGeneration || emit.isDone) return;

    switch (result) {
      case Ok(value: final value?):
        emit(
          _stateWithServerData(
            value.data,
            isLoadingData: false,
            hasActiveCustomBitcoinOnionServer:
                value.hasActiveCustomBitcoinOnionServer,
          ),
        );
      case Ok():
        return;
      case Err(:final failure):
        emit(
          state.copyWith(
            isLoadingData: false,
            electrumServersError: ElectrumServersLoadFailure(
              failure.logMessage,
            ),
          ),
        );
    }
  }

  ElectrumSettingsState _stateWithServerData(
    ElectrumServerChecks response, {
    required bool isLoadingData,
    bool? hasActiveCustomBitcoinOnionServer,
  }) {
    final statuses = response.serverStatuses;
    final servers = response.servers;
    final settings = response.settings;

    ElectrumServerViewModel toViewModel(ElectrumEndpoint server) =>
        ElectrumServerViewModel(
          url: server.url,
          network: server.network,
          status: statuses[server.url] ?? ElectrumServerStatus.unknown,
          priority: server.priority,
        );

    return state.copyWith(
      environment: settings.network.environment,
      defaultServers: servers
          .where((server) => !server.isCustom)
          .map(toViewModel)
          .toList(),
      customServers: servers
          .where((server) => server.isCustom)
          .map(toViewModel)
          .toList(),
      advancedOptions: ElectrumAdvancedOptionsViewModel(
        retry: settings.retry,
        timeout: settings.timeout,
        stopGap: settings.stopGap,
        validateDomain: settings.validateDomain,
        socks5: settings.socks5,
      ),
      isLoadingData: isLoadingData,
      hasActiveCustomBitcoinOnionServer:
          hasActiveCustomBitcoinOnionServer ??
          state.hasActiveCustomBitcoinOnionServer,
    );
  }

  Future<void> _onCustomServerAdded(
    ElectrumCustomServerAdded event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    final environment = state.environment;
    if (environment == null) {
      emit(
        state.copyWith(
          electrumServersError: const ElectrumServersLoadFailure(),
        ),
      );
      return;
    }
    _invalidateLoadGeneration();
    emit(
      state.copyWith(isAddingCustomServer: true, electrumServersError: null),
    );
    final network = ElectrumServerNetwork.fromEnvironment(
      environment: environment,
      isLiquid: state.isLiquid,
    );
    final lastPriority = state
        .getServersSortedByPriority(isCustom: true)
        .lastOrNull
        ?.priority;
    switch (await _addServer.execute(
      url: event.url,
      enableSsl: event.enableSsl,
      network: network,
      lastPriority: lastPriority,
      currentOptions: () => _currentOptions(network),
    )) {
      case Ok(:final value):
        final server = value.server;
        final newServer = ElectrumServerViewModel(
          network: network,
          url: server.url,
          status: value.status,
          priority: server.priority,
        );
        emit(
          state.copyWith(
            customServers: [...state.customServers, newServer],
            isAddingCustomServer: false,
            advancedOptions:
                _optionsViewModel(value.options) ?? state.advancedOptions,
            hasActiveCustomBitcoinOnionServer:
                value.hasActiveCustomBitcoinOnionServer,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            isAddingCustomServer: false,
            electrumServersError: failure,
          ),
        );
    }
  }

  Future<void> _onCustomServersPrioritized(
    ElectrumCustomServersPrioritized event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    final environment = state.environment;
    if (environment == null) {
      emit(
        state.copyWith(
          electrumServersError: const ElectrumServersLoadFailure(),
        ),
      );
      return;
    }
    _invalidateLoadGeneration();
    emit(
      state.copyWith(
        isPrioritizingCustomServer: true,
        electrumServersError: null,
      ),
    );
    final currentServers = state.getServersSortedByPriority(isCustom: true);

    final network = ElectrumServerNetwork.fromEnvironment(
      environment: environment,
      isLiquid: state.isLiquid,
    );
    switch (await _prioritizeServers.execute(
      urls: currentServers.map((server) => server.url).toList(),
      network: network,
      oldIndex: event.movedFromListIndex,
      newIndex: event.movedToListIndex,
    )) {
      case Ok(:final value):
        final updatedServers = value.servers
            .map(
              (dto) => ElectrumServerViewModel(
                network: dto.network,
                url: dto.url,
                status: currentServers
                    .firstWhere((s) => s.url == dto.url)
                    .status, // Preserve existing status
                priority: dto.priority,
              ),
            )
            .toList();
        emit(
          state.copyWith(
            customServers: updatedServers,
            isPrioritizingCustomServer: false,
            hasActiveCustomBitcoinOnionServer:
                value.hasActiveCustomBitcoinOnionServer,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            isPrioritizingCustomServer: false,
            electrumServersError: failure,
          ),
        );
    }
  }

  Future<void> _onCustomServerDeleted(
    ElectrumCustomServerDeleted event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    final environment = state.environment;
    if (environment == null) {
      emit(
        state.copyWith(
          electrumServersError: const ElectrumServersLoadFailure(),
        ),
      );
      return;
    }
    _invalidateLoadGeneration();
    emit(
      state.copyWith(isDeletingCustomServer: true, electrumServersError: null),
    );

    final network = ElectrumServerNetwork.fromEnvironment(
      environment: environment,
      isLiquid: state.isLiquid,
    );

    switch (await _removeServer.execute(
      network: network,
      serverNetwork: event.server.network,
      url: event.server.url,
      otherServersRemain: () =>
          state.customServers.any((server) => server.url != event.server.url),
      currentOptions: () => _currentOptions(network),
    )) {
      case Ok(:final value):
        emit(
          state.copyWith(
            customServers: state.customServers
                .where((server) => server.url != event.server.url)
                .toList(),
            isDeletingCustomServer: false,
            advancedOptions:
                _optionsViewModel(value.options) ?? state.advancedOptions,
            hasActiveCustomBitcoinOnionServer:
                value.hasActiveCustomBitcoinOnionServer,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            isDeletingCustomServer: false,
            electrumServersError: failure,
          ),
        );
    }
  }

  Future<void> _onAdvancedOptionsSaved(
    ElectrumAdvancedOptionsSaved event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    final environment = state.environment;
    if (environment == null) {
      emit(
        state.copyWith(
          electrumServersError: const ElectrumServersLoadFailure(),
        ),
      );
      return;
    }
    _invalidateLoadGeneration();
    emit(
      state.copyWith(isSavingAdvancedOptions: true, advancedOptionsError: null),
    );

    final network = ElectrumServerNetwork.fromEnvironment(
      environment: environment,
      isLiquid: state.isLiquid,
    );

    // Parse the raw text inputs. Non-numeric input is a presentation-level
    // validation failure echoing what the user typed (sanitized, not raw
    // exception text).
    final stopGap = int.tryParse(event.stopGap);
    if (stopGap == null) {
      emit(
        state.copyWith(
          isSavingAdvancedOptions: false,
          advancedOptionsError: AdvancedOptionsInvalidStopGapFailure(
            event.stopGap,
          ),
        ),
      );
      return;
    }
    final timeout = int.tryParse(event.timeout);
    if (timeout == null) {
      emit(
        state.copyWith(
          isSavingAdvancedOptions: false,
          advancedOptionsError: AdvancedOptionsInvalidTimeoutFailure(
            event.timeout,
          ),
        ),
      );
      return;
    }
    final retry = int.tryParse(event.retry);
    if (retry == null) {
      emit(
        state.copyWith(
          isSavingAdvancedOptions: false,
          advancedOptionsError: AdvancedOptionsInvalidRetryFailure(event.retry),
        ),
      );
      return;
    }

    switch (await _updateSettings.execute(
      ElectrumOptions(
        stopGap: stopGap,
        timeout: timeout,
        retry: retry,
        validateDomain: event.validateDomain,
        socks5: event.socks5,
        network: network,
      ),
    )) {
      case Ok(:final value):
        emit(
          state.copyWith(
            advancedOptions: _optionsViewModel(value),
            isSavingAdvancedOptions: false,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            isSavingAdvancedOptions: false,
            advancedOptionsError: failure,
          ),
        );
    }
  }

  Future<void> _onAdvancedOptionsReset(
    ElectrumAdvancedOptionsReset event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    // Just remove the state error here, the UI will reset the fields itself
    emit(state.copyWith(advancedOptionsError: null));
  }

  void _invalidateLoadGeneration() {
    _loadGeneration++;
  }

  ElectrumOptions? _currentOptions(ElectrumServerNetwork network) {
    final current = state.advancedOptions;
    if (current == null) return null;
    return ElectrumOptions(
      stopGap: current.stopGap,
      timeout: current.timeout,
      retry: current.retry,
      validateDomain: current.validateDomain,
      socks5: current.socks5,
      network: network,
    );
  }

  ElectrumAdvancedOptionsViewModel? _optionsViewModel(
    ElectrumOptions? options,
  ) => options == null
      ? null
      : ElectrumAdvancedOptionsViewModel(
          retry: options.retry,
          timeout: options.timeout,
          stopGap: options.stopGap,
          validateDomain: options.validateDomain,
          socks5: options.socks5,
        );
}
