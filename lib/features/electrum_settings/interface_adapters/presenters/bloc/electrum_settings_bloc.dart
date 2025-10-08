import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/delete_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/load_electrum_server_data_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/set_advanced_electrum_options_request.dart';
import 'package:bb_mobile/core/electrum/application/errors/set_advanced_electrum_options_exception.dart'
    as advanced_options_application_errors;
import 'package:bb_mobile/core/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_settings_exception.dart'
    as advanced_options_domain_errors;
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/errors/advanced_options_exception.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/errors/electrum_servers_exception.dart';
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
  final DeleteCustomServerUsecase _deleteCustomServerUsecase;
  final SetAdvancedElectrumOptionsUsecase _setAdvancedElectrumOptionsUsecase;

  ElectrumSettingsBloc({
    required LoadElectrumServerDataUsecase loadElectrumServerDataUsecase,
    required AddCustomServerUsecase addCustomServerUsecase,
    required DeleteCustomServerUsecase deleteCustomServerUsecase,
    required SetAdvancedElectrumOptionsUsecase
    setAdvancedElectrumOptionsUsecase,
  }) : _loadElectrumServerDataUsecase = loadElectrumServerDataUsecase,
       _addCustomServerUsecase = addCustomServerUsecase,
       _deleteCustomServerUsecase = deleteCustomServerUsecase,
       _setAdvancedElectrumOptionsUsecase = setAdvancedElectrumOptionsUsecase,
       super(const ElectrumSettingsState()) {
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
    try {
      final data = await _loadElectrumServerDataUsecase.execute(
        LoadElectrumServerDataRequest(isLiquid: event.isLiquid),
      );
      final statuses = data.serverStatuses;
      final servers = data.servers;
      final settings = data.settings;
      emit(
        state.copyWith(
          environment:
              settings.network.isTestnet
                  ? ElectrumEnvironment.testnet
                  : ElectrumEnvironment.mainnet,
          defaultServers:
              servers
                  .where((s) => !s.isCustom)
                  .map(
                    (s) => ElectrumServerViewModel(
                      url: s.url,
                      status: statuses[s.url]!,
                      priority: s.priority,
                    ),
                  )
                  .toList(),
          customServers:
              servers
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
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(electrumServersError: LoadFailedException(e.toString())),
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

    try {
      final request = AddCustomServerRequest(
        url: event.url,
        network: network,
        isCustom: true,
        priority: priority,
      );
      final status = await _addCustomServerUsecase.execute(request);

      // Add the new server to the list in the state
      //  with the returned status so the UI can reflect it immediately
      final newServer = ElectrumServerViewModel(
        url: event.url,
        status: status,
        priority: priority,
      );
      final updatedCustomServers = [...state.customServers, newServer];
      emit(state.copyWith(customServers: updatedCustomServers));
    } catch (e) {
      // If there's an error, emit the error state
      emit(
        state.copyWith(electrumServersError: AddFailedException(e.toString())),
      );
    } finally {
      // Ensure we reset the adding state
      emit(state.copyWith(isAddingCustomServer: false));
    }
  }

  Future<void> _onCustomServersPrioritized(
    ElectrumCustomServersPrioritized event,
    Emitter<ElectrumSettingsState> emit,
  ) async {}

  Future<void> _onCustomServerDeleted(
    ElectrumCustomServerDeleted event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    emit(
      state.copyWith(isDeletingCustomServer: true, electrumServersError: null),
    );

    final sortedServers = state.getServersSortedByPriority(isCustom: true);
    try {
      final request = DeleteCustomServerRequest(url: event.server.url);
      await _deleteCustomServerUsecase.execute(request);
      // Remove the server from the list in the state
      final updatedCustomServers =
          sortedServers.where((s) => s.url != event.server.url).toList();
      emit(state.copyWith(customServers: updatedCustomServers));
    } catch (e) {
      emit(
        state.copyWith(
          electrumServersError: DeleteFailedException(e.toString()),
        ),
      );
    } finally {
      emit(state.copyWith(isDeletingCustomServer: false));
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

    final stopGap = int.tryParse(event.stopGap);
    if (stopGap == null) {
      throw InvalidStopGapException(event.stopGap);
    }
    final timeout = int.tryParse(event.timeout);
    if (timeout == null) {
      throw InvalidTimeoutException(event.timeout);
    }
    final retry = int.tryParse(event.retry);
    if (retry == null) {
      throw InvalidRetryException(event.retry);
    }

    try {
      final request = SetAdvancedElectrumOptionsRequest(
        stopGap: stopGap,
        timeout: timeout,
        retry: retry,
        validateDomain: event.validateDomain,
        socks5: event.socks5 ?? '',
        network: network,
      );
      await _setAdvancedElectrumOptionsUsecase.execute(request);

      // Update the state with the new values
      final updatedOptions = ElectrumAdvancedOptionsViewModel(
        retry: retry,
        timeout: timeout,
        stopGap: stopGap,
        validateDomain: event.validateDomain,
        socks5: event.socks5,
      );
      emit(state.copyWith(advancedOptions: updatedOptions));
    } on advanced_options_domain_errors.InvalidStopGapException catch (e) {
      emit(
        state.copyWith(
          advancedOptionsError: InvalidStopGapException(e.value.toString()),
        ),
      );
    } on advanced_options_domain_errors.InvalidTimeoutException catch (e) {
      emit(
        state.copyWith(
          advancedOptionsError: InvalidTimeoutException(e.value.toString()),
        ),
      );
    } on advanced_options_domain_errors.InvalidRetryException catch (e) {
      emit(
        state.copyWith(
          advancedOptionsError: InvalidRetryException(e.value.toString()),
        ),
      );
    } on advanced_options_application_errors.SaveFailedException catch (e) {
      emit(
        state.copyWith(advancedOptionsError: SaveFailedException(e.toString())),
      );
    } catch (e) {
      emit(
        state.copyWith(advancedOptionsError: UnknownException(e.toString())),
      );
    } finally {
      emit(state.copyWith(isSavingAdvancedOptions: false));
    }
  }

  Future<void> _onAdvancedOptionsReset(
    ElectrumAdvancedOptionsReset event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    // Just remove the state error here, the UI will reset the fields itself
    emit(state.copyWith(advancedOptionsError: null));
  }
}
