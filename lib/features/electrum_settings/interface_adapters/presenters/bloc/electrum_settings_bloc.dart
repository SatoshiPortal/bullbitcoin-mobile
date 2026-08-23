import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/delete_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/load_electrum_server_data_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/set_advanced_electrum_options_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/set_custom_servers_priority_request.dart';
import 'package:bb_mobile/core/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_custom_servers_priority_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart'
    as core;
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/utils/electrum_url_parser.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_settings_failure.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/view_models/electrum_advanced_options_view_model.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/view_models/electrum_server_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_settings_bloc.freezed.dart';
part 'electrum_settings_event.dart';
part 'electrum_settings_state.dart';

class ElectrumSettingsBloc
    extends Bloc<ElectrumSettingsEvent, ElectrumSettingsState> {
  final LoadElectrumServerDataUsecase _loadElectrumServerDataUsecase;
  final AddCustomServerUsecase _addCustomServerUsecase;
  final SetCustomServersPriorityUsecase _setCustomServersPriorityUsecase;
  final DeleteCustomServerUsecase _deleteCustomServerUsecase;
  final SetAdvancedElectrumOptionsUsecase _setAdvancedElectrumOptionsUsecase;

  ElectrumSettingsBloc({
    required this._loadElectrumServerDataUsecase,
    required this._addCustomServerUsecase,
    required this._setCustomServersPriorityUsecase,
    required this._deleteCustomServerUsecase,
    required this._setAdvancedElectrumOptionsUsecase,
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
    emit(
      state.copyWith(
        isLiquid: event.isLiquid,
        isLoadingData: true,
        electrumServersError: null,
        advancedOptionsError: null,
      ),
    );

    switch (await _loadElectrumServerDataUsecase.execute(
      LoadElectrumServerDataRequest(isLiquid: event.isLiquid),
    )) {
      case Ok(:final value):
        final statuses = value.serverStatuses;
        final servers = value.servers;
        final settings = value.settings;
        emit(
          state.copyWith(
            environment: settings.network.isTestnet
                ? ElectrumEnvironment.testnet
                : ElectrumEnvironment.mainnet,
            defaultServers: servers
                .where((s) => !s.isCustom)
                .map(
                  (s) => ElectrumServerViewModel(
                    url: s.url,
                    status: statuses[s.url]!,
                    priority: s.priority,
                  ),
                )
                .toList(),
            customServers: servers
                .where((s) => s.isCustom)
                .map(
                  (s) => ElectrumServerViewModel(
                    url: s.url,
                    status: statuses[s.url]!,
                    priority: s.priority,
                  ),
                )
                .toList(),
            advancedOptions: ElectrumAdvancedOptionsViewModel(
              retry: settings.retry,
              timeout: settings.timeout,
              stopGap: settings.stopGap,
              validateDomain: settings.validateDomain,
              socks5: settings.socks5,
            ),
            isLoadingData: false,
          ),
        );
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

  Future<void> _onCustomServerAdded(
    ElectrumCustomServerAdded event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    emit(
      state.copyWith(isAddingCustomServer: true, electrumServersError: null),
    );
    final isTestnet = state.environment == ElectrumEnvironment.testnet;
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: state.isLiquid,
    );
    final sortedServers = state.getServersSortedByPriority(isCustom: true);
    final currentLastPriority = sortedServers.lastOrNull?.priority;
    final priority = currentLastPriority == null ? 0 : currentLastPriority + 1;

    // Parse the URL to extract the clean URL (without :s or :t suffix)
    final parsedUrl = ElectrumUrlParser.tryParse(event.url);
    final cleanUrl = parsedUrl?.cleanUrl ?? event.url;

    final request = AddCustomServerRequest(
      server: ElectrumServerDto(
        url: cleanUrl,
        network: network,
        isCustom: true,
        priority: priority,
        enableSsl: event.enableSsl,
      ),
    );

    switch (await _addCustomServerUsecase.execute(request)) {
      case Ok(:final value):
        final newServer = ElectrumServerViewModel(
          url: event.enableSsl ? 'ssl://$cleanUrl' : 'tcp://$cleanUrl',
          status: value,
          priority: priority,
        );
        // Custom servers (self-hosted, Tailscale, etc.) commonly present a
        // certificate that fails strict domain validation, so switching to
        // one disables it automatically.
        final updatedAdvancedOptions = await _setValidateDomain(
          network: network,
          validateDomain: false,
        );
        emit(
          state.copyWith(
            customServers: [...state.customServers, newServer],
            isAddingCustomServer: false,
            advancedOptions: updatedAdvancedOptions ?? state.advancedOptions,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            isAddingCustomServer: false,
            electrumServersError: _toAddFailure(failure),
          ),
        );
    }
  }

  Future<void> _onCustomServersPrioritized(
    ElectrumCustomServersPrioritized event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    emit(
      state.copyWith(
        isPrioritizingCustomServer: true,
        electrumServersError: null,
      ),
    );
    final currentServers = state.getServersSortedByPriority(isCustom: true);
    final oldIndex = event.movedFromListIndex;
    final newIndex = event.movedToListIndex;

    final reorderedServers = List<ElectrumServerViewModel>.from(currentServers);
    if (oldIndex < newIndex) {
      reorderedServers.insert(
        newIndex - 1,
        reorderedServers.removeAt(oldIndex),
      );
    } else {
      reorderedServers.insert(newIndex, reorderedServers.removeAt(oldIndex));
    }

    final request = SetCustomServersPriorityRequest(
      servers: reorderedServers
          .map(
            (e) => ElectrumServerDto(
              isCustom: true,
              url: e.url,
              network: ElectrumServerNetwork.fromEnvironment(
                isTestnet: state.environment == ElectrumEnvironment.testnet,
                isLiquid: state.isLiquid,
              ),
              priority: e.priority,
            ),
          )
          .toList(),
    );

    switch (await _setCustomServersPriorityUsecase.execute(request)) {
      case Ok(:final value):
        final updatedServers = value.servers
            .map(
              (dto) => ElectrumServerViewModel(
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
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            isPrioritizingCustomServer: false,
            electrumServersError: ElectrumServersSavePriorityFailure(
              failure.logMessage,
            ),
          ),
        );
    }
  }

  Future<void> _onCustomServerDeleted(
    ElectrumCustomServerDeleted event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    emit(
      state.copyWith(isDeletingCustomServer: true, electrumServersError: null),
    );

    final isTestnet = state.environment == ElectrumEnvironment.testnet;
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: state.isLiquid,
    );

    switch (await _deleteCustomServerUsecase.execute(
      DeleteCustomServerRequest(url: event.server.url),
    )) {
      case Ok():
        // Re-derive from the latest state, not a pre-await snapshot: a
        // custom server added concurrently while this delete was in flight
        // must not be dropped from the list, and must not be missed by the
        // validateDomain "last custom server" check below.
        final updatedCustomServers = state.customServers
            .where((s) => s.url != event.server.url)
            .toList();
        // Deleting the last custom server falls back to the default
        // servers, so domain validation is re-enabled for them.
        final updatedAdvancedOptions = updatedCustomServers.isEmpty
            ? await _setValidateDomain(network: network, validateDomain: true)
            : null;
        emit(
          state.copyWith(
            customServers: updatedCustomServers,
            isDeletingCustomServer: false,
            advancedOptions: updatedAdvancedOptions ?? state.advancedOptions,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            isDeletingCustomServer: false,
            electrumServersError: ElectrumServersDeleteFailure(
              failure.logMessage,
            ),
          ),
        );
    }
  }

  Future<void> _onAdvancedOptionsSaved(
    ElectrumAdvancedOptionsSaved event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    emit(
      state.copyWith(isSavingAdvancedOptions: true, advancedOptionsError: null),
    );

    final isTestnet = state.environment == ElectrumEnvironment.testnet;
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
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

    final request = SetAdvancedElectrumOptionsRequest(
      options: ElectrumSettingsDto(
        stopGap: stopGap,
        timeout: timeout,
        retry: retry,
        validateDomain: event.validateDomain,
        socks5: event.socks5,
        network: network,
      ),
    );

    switch (await _setAdvancedElectrumOptionsUsecase.execute(request)) {
      case Ok():
        emit(
          state.copyWith(
            advancedOptions: ElectrumAdvancedOptionsViewModel(
              retry: retry,
              timeout: timeout,
              stopGap: stopGap,
              validateDomain: event.validateDomain,
              socks5: event.socks5,
            ),
            isSavingAdvancedOptions: false,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            isSavingAdvancedOptions: false,
            advancedOptionsError: _toAdvancedFailure(failure),
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

  // Auto-toggles validateDomain to match the active server tier (off for
  // custom, on for defaults). Best-effort: the server list change already
  // succeeded, so a failure here is logged rather than surfaced as an
  // add/delete-server error. Returns null when nothing changed.
  Future<ElectrumAdvancedOptionsViewModel?> _setValidateDomain({
    required ElectrumServerNetwork network,
    required bool validateDomain,
  }) async {
    final current = state.advancedOptions;
    if (current == null || current.validateDomain == validateDomain) {
      return null;
    }

    final request = SetAdvancedElectrumOptionsRequest(
      options: ElectrumSettingsDto(
        stopGap: current.stopGap,
        timeout: current.timeout,
        retry: current.retry,
        validateDomain: validateDomain,
        socks5: current.socks5,
        network: network,
      ),
    );

    switch (await _setAdvancedElectrumOptionsUsecase.execute(request)) {
      case Ok():
        return current.copyWith(validateDomain: validateDomain);
      case Err(:final failure):
        log.warning(
          'Failed to auto-toggle validateDomain to $validateDomain',
          error: failure,
        );
        return null;
    }
  }

  // Lift a core failure into the server-list feature failure for the add flow.
  ElectrumServersFailure _toAddFailure(core.ElectrumFailure failure) =>
      switch (failure) {
        core.ElectrumServerAlreadyExistsFailure() =>
          ElectrumServersAlreadyExistsFailure(failure.logMessage),
        core.ElectrumServerUnreachableFailure() =>
          ElectrumServersUnreachableFailure(failure.logMessage),
        core.ElectrumExternalTorProxyUnavailableFailure() =>
          ElectrumServersExternalTorProxyUnavailableFailure(
            failure.logMessage,
          ),
        core.ElectrumUnexpectedFailure() => ElectrumServersUnexpectedFailure(
          failure.logMessage,
        ),
        // Any other add-flow failure shares the "failed to add" message; the
        // precise core variant is preserved in logs.
        _ => ElectrumServersAddFailure(failure.logMessage),
      };

  // Lift a core failure into the advanced-options feature failure.
  AdvancedOptionsFailure _toAdvancedFailure(core.ElectrumFailure failure) =>
      switch (failure) {
        core.ElectrumInvalidStopGapFailure(:final value) =>
          AdvancedOptionsInvalidStopGapFailure(
            value.toString(),
            failure.logMessage,
          ),
        core.ElectrumInvalidTimeoutFailure(:final value) =>
          AdvancedOptionsInvalidTimeoutFailure(
            value.toString(),
            failure.logMessage,
          ),
        core.ElectrumInvalidRetryFailure(:final value) =>
          AdvancedOptionsInvalidRetryFailure(
            value.toString(),
            failure.logMessage,
          ),
        core.ElectrumSaveFailure() => AdvancedOptionsSaveFailure(
          failure.logMessage,
        ),
        // Load failure (fetch before save) + anything else → generic message.
        _ => AdvancedOptionsUnexpectedFailure(failure.logMessage),
      };
}
