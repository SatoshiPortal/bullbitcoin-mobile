import 'package:electrum/electrum.dart';
import 'package:get_it/get_it.dart';

import 'domain/add_electrum_server_usecase.dart';
import 'domain/load_electrum_settings_usecase.dart';
import 'domain/prioritize_electrum_servers_usecase.dart';
import 'domain/remove_electrum_server_usecase.dart';
import 'domain/update_electrum_settings_usecase.dart';
import 'presentation/electrum_settings_bloc.dart';

class ElectrumSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<ElectrumSettingsBloc>(() {
      final servers = locator<Electrum>().servers;
      final updateSettings = UpdateElectrumSettingsUsecase(servers.options);
      return ElectrumSettingsBloc(
        loadSettings: LoadElectrumSettingsUsecase(servers),
        addServer: AddElectrumServerUsecase(servers, updateSettings),
        prioritizeServers: PrioritizeElectrumServersUsecase(servers),
        removeServer: RemoveElectrumServerUsecase(servers, updateSettings),
        updateSettings: updateSettings,
      );
    });
  }
}
