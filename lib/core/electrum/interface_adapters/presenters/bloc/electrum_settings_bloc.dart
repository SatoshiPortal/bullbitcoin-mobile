import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/errors/advanced_options_error.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/errors/electrum_servers_error.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/errors/new_custom_server_error.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/view_models/electrum_advanced_options_view_model.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/presenters/view_models/electrum_server_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_settings_event.dart';
part 'electrum_settings_state.dart';
part 'electrum_settings_bloc.freezed.dart';

class ElectrumSettingsBloc
    extends Bloc<ElectrumSettingsEvent, ElectrumSettingsState> {
  final LoadElectrumServerDataUsecase _loadElectrumServerDataUsecase;

  ElectrumSettingsBloc({
    required LoadElectrumServerDataUsecase loadElectrumServerDataUsecase,
  }) : _loadElectrumServerDataUsecase = loadElectrumServerDataUsecase,
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
          defaultBitcoinServers:
              bitcoinServers
                  .where((s) => !s.isCustom)
                  .map(
                    (s) => ElectrumServerViewModel(
                      url: s.url,
                      status: statuses[s.url]!,
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
  ) async {}

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
