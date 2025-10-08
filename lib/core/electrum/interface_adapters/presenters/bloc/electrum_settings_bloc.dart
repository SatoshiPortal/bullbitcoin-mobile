import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/delete_custom_server_request.dart';
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
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/errors/advanced_options_exception.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/errors/electrum_servers_exception.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/view_models/electrum_advanced_options_view_model.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/view_models/electrum_server_view_model.dart';
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
       super(const ElectrumSettingsState.loading()) {
    on<ElectrumSettingsLoaded>(_onLoaded);
    on<ElectrumCustomServerAdded>(_onCustomServerAdded);
    on<ElectrumCustomServersPrioritized>(_onCustomServersPrioritized);
    on<ElectrumCustomServerDeleted>(_onCustomServerDeleted);
    on<ElectrumAdvancedOptionsSaved>(_onAdvancedOptionsSaved);
  }

  Future<void> _onLoaded(
    ElectrumSettingsLoaded event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    emit(state.toLoadingState());
    try {
      final data = await _loadElectrumServerDataUsecase.execute();
      final statuses = data.serverStatuses;
      final bitcoinServers =
          data.servers.where((s) => !s.network.isLiquid).toList();
      final liquidServers =
          data.servers.where((s) => s.network.isLiquid).toList();
      final bitcoinSettings = data.bitcoinSettings;
      final liquidSettings = data.liquidSettings;
      emit(
        ElectrumSettingsState.loaded(
          environment:
              bitcoinSettings.network.isTestnet
                  ? ElectrumEnvironment.testnet
                  : ElectrumEnvironment.mainnet,
          defaultBitcoinServers:
              bitcoinServers
                  .where((s) => !s.isCustom)
                  .map(
                    (s) => ElectrumServerViewModel(
                      url: s.url,
                      status: statuses[s.url]!,
                      priority: s.priority,
                    ),
                  )
                  .toList(),

          customBitcoinServers:
              bitcoinServers
                  .where((s) => s.isCustom)
                  .map(
                    (s) => ElectrumServerViewModel(
                      url: s.url,
                      status: statuses[s.url]!,
                      priority: s.priority,
                    ),
                  )
                  .toList(),
          defaultLiquidServers:
              liquidServers
                  .where((s) => !s.isCustom)
                  .map(
                    (s) => ElectrumServerViewModel(
                      url: s.url,
                      status: statuses[s.url]!,
                      priority: s.priority,
                    ),
                  )
                  .toList(),
          customLiquidServers:
              liquidServers
                  .where((s) => s.isCustom)
                  .map(
                    (s) => ElectrumServerViewModel(
                      url: s.url,
                      status: statuses[s.url]!,
                      priority: s.priority,
                    ),
                  )
                  .toList(),
          bitcoinAdvancedOptions: ElectrumAdvancedOptionsViewModel(
            retry: bitcoinSettings.retry,
            timeout: bitcoinSettings.timeout,
            stopGap: bitcoinSettings.stopGap,
            validateDomain: bitcoinSettings.validateDomain,
            socks5: bitcoinSettings.socks5,
          ),
          liquidAdvancedOptions: ElectrumAdvancedOptionsViewModel(
            retry: liquidSettings.retry,
            timeout: liquidSettings.timeout,
            stopGap: liquidSettings.stopGap,
            validateDomain: liquidSettings.validateDomain,
            socks5: liquidSettings.socks5,
          ),
        ),
      );
    } catch (e) {
      emit(
        ElectrumSettingsState.loaded(
          environment: state.environment!,
          defaultBitcoinServers: state.defaultBitcoinServers,
          customBitcoinServers: state.customBitcoinServers,
          defaultLiquidServers: state.defaultLiquidServers,
          customLiquidServers: state.customLiquidServers,
          bitcoinAdvancedOptions: state.bitcoinAdvancedOptions,
          liquidAdvancedOptions: state.liquidAdvancedOptions,
          electrumServersError: LoadFailedException(e.toString()),
        ),
      );
    }
  }

  Future<void> _onCustomServerAdded(
    ElectrumCustomServerAdded event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    // Only allow adding a custom server if we're in a loaded state
    if (state is! ElectrumSettingsLoadedState) {
      return;
    }
    final currentState = state as ElectrumSettingsLoadedState;
    emit(
      currentState.copyWith(
        isAddingCustomServer: true,
        electrumServersError: null,
      ),
    );
    final isTestnet = currentState.environment == ElectrumEnvironment.testnet;
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: event.isLiquid,
    );
    final sortedServers = currentState.getServersSortedByPriority(
      isLiquid: event.isLiquid,
      isCustom: true,
    );
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
      final updatedCustomServers =
          event.isLiquid
              ? [...currentState.customLiquidServers, newServer]
              : [...currentState.customBitcoinServers, newServer];
      emit(
        currentState.copyWith(
          customLiquidServers:
              event.isLiquid
                  ? updatedCustomServers
                  : currentState.customLiquidServers,
          customBitcoinServers:
              event.isLiquid
                  ? currentState.customBitcoinServers
                  : updatedCustomServers,
        ),
      );
    } catch (e) {
      // If there's an error, emit the error state
      emit(
        currentState.copyWith(
          electrumServersError: AddFailedException(e.toString()),
        ),
      );
    } finally {
      // Ensure we reset the adding state
      emit(currentState.copyWith(isAddingCustomServer: false));
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
    // Only allow deleting a custom server if we're in a loaded state
    if (state is! ElectrumSettingsLoadedState) {
      return;
    }
    final currentState = state as ElectrumSettingsLoadedState;
    emit(
      currentState.copyWith(
        isDeletingCustomServer: true,
        electrumServersError: null,
      ),
    );

    final sortedServers = currentState.getServersSortedByPriority(
      isLiquid: event.isLiquid,
      isCustom: true,
    );
    try {
      final request = DeleteCustomServerRequest(url: event.server.url);
      await _deleteCustomServerUsecase.execute(request);
      // Remove the server from the list in the state
      final updatedCustomServers =
          sortedServers.where((s) => s.url != event.server.url).toList();
      emit(
        currentState.copyWith(
          customLiquidServers:
              event.isLiquid
                  ? updatedCustomServers
                  : currentState.customLiquidServers,
          customBitcoinServers:
              event.isLiquid
                  ? currentState.customBitcoinServers
                  : updatedCustomServers,
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          electrumServersError: DeleteFailedException(e.toString()),
        ),
      );
    } finally {
      emit(currentState.copyWith(isDeletingCustomServer: false));
    }
  }

  Future<void> _onAdvancedOptionsSaved(
    ElectrumAdvancedOptionsSaved event,
    Emitter<ElectrumSettingsState> emit,
  ) async {
    // Only allow setting advanced options if we're in a loaded state
    if (state is! ElectrumSettingsLoadedState) {
      return;
    }
    final currentState = state as ElectrumSettingsLoadedState;
    emit(
      currentState.copyWith(
        isSavingAdvancedOptions: true,
        advancedOptionsError: null,
      ),
    );

    final isTestnet = currentState.environment == ElectrumEnvironment.testnet;
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: event.isLiquid,
    );

    try {
      final request = SetAdvancedElectrumOptionsRequest(
        stopGap: event.stopGap,
        timeout: event.timeout,
        retry: event.retry,
        validateDomain: event.validateDomain,
        socks5: event.socks5 ?? '',
        network: network,
      );
      await _setAdvancedElectrumOptionsUsecase.execute(request);

      // Update the state with the new values
      final updatedOptions = ElectrumAdvancedOptionsViewModel(
        retry: event.retry,
        timeout: event.timeout,
        stopGap: event.stopGap,
        validateDomain: event.validateDomain,
        socks5: event.socks5,
      );
      emit(
        currentState.copyWith(
          bitcoinAdvancedOptions:
              event.isLiquid
                  ? currentState.bitcoinAdvancedOptions
                  : updatedOptions,
          liquidAdvancedOptions:
              event.isLiquid
                  ? updatedOptions
                  : currentState.liquidAdvancedOptions,
        ),
      );
    } on advanced_options_domain_errors.InvalidStopGapException catch (e) {
      emit(
        currentState.copyWith(
          advancedOptionsError: InvalidStopGapException(e.value),
        ),
      );
    } on advanced_options_domain_errors.InvalidTimeoutException catch (e) {
      emit(
        currentState.copyWith(
          advancedOptionsError: InvalidTimeoutException(e.value),
        ),
      );
    } on advanced_options_domain_errors.InvalidRetryException catch (e) {
      emit(
        currentState.copyWith(
          advancedOptionsError: InvalidRetryException(e.value),
        ),
      );
    } on advanced_options_application_errors.SaveFailedException catch (e) {
      emit(
        currentState.copyWith(
          advancedOptionsError: SaveFailedException(e.toString()),
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          advancedOptionsError: UnknownException(e.toString()),
        ),
      );
    } finally {
      emit(currentState.copyWith(isSavingAdvancedOptions: false));
    }
  }
}
