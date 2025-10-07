import 'package:bb_mobile/core/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/errors/add_custom_server_error.dart'
    as add_custom_server_error;
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/errors/add_custom_server_error.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/errors/advanced_options_error.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/errors/electrum_servers_error.dart';
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

  ElectrumSettingsBloc({
    required LoadElectrumServerDataUsecase loadElectrumServerDataUsecase,
    required AddCustomServerUsecase addCustomServerUsecase,
  }) : _loadElectrumServerDataUsecase = loadElectrumServerDataUsecase,
       _addCustomServerUsecase = addCustomServerUsecase,
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
          electrumServersError: LoadFailedError(e.toString()),
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
        addCustomServerError: null,
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
      final status = await _addCustomServerUsecase.execute(
        url: event.url,
        network: network,
        isCustom: true,
        priority: priority,
      );
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
          addCustomServerError: add_custom_server_error.SaveFailedError(
            e.toString(),
          ),
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
  ) async {}

  Future<void> _onAdvancedOptionsSaved(
    ElectrumAdvancedOptionsSaved event,
    Emitter<ElectrumSettingsState> emit,
  ) async {}
}
