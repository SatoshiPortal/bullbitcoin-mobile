import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

import 'domain/add_electrum_server_usecase.dart';
import 'domain/load_electrum_settings_usecase.dart';
import 'domain/prioritize_electrum_servers_usecase.dart';
import 'domain/remove_electrum_server_usecase.dart';
import 'domain/update_electrum_settings_usecase.dart';
import 'presentation/electrum_settings_bloc.dart';

ElectrumSettingsBloc createElectrumSettingsBloc(
  Electrum electrum,
  Future<NetworkEnv> Function() readEnvironment,
) {
  final servers = electrum.servers;
  final updateSettings = UpdateElectrumSettingsUsecase(servers.options);
  return ElectrumSettingsBloc(
    loadSettings: LoadElectrumSettingsUsecase(servers, readEnvironment),
    addServer: AddElectrumServerUsecase(servers, updateSettings),
    prioritizeServers: PrioritizeElectrumServersUsecase(servers),
    removeServer: RemoveElectrumServerUsecase(servers, updateSettings),
    updateSettings: updateSettings,
  );
}
