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
      final updateSettings = UpdateElectrumSettingsUsecase(
        locator<SetAdvancedElectrumOptionsUsecase>(),
      );
      final hasActiveOnionServer =
          locator<HasActiveCustomBitcoinOnionServerUsecase>();
      return ElectrumSettingsBloc(
        loadSettings: LoadElectrumSettingsUsecase(
          locator<LoadElectrumServerDataUsecase>(),
          hasActiveOnionServer,
        ),
        addServer: AddElectrumServerUsecase(
          locator<AddCustomServerUsecase>(),
          updateSettings,
          hasActiveOnionServer,
        ),
        prioritizeServers: PrioritizeElectrumServersUsecase(
          locator<SetCustomServersPriorityUsecase>(),
          hasActiveOnionServer,
        ),
        removeServer: RemoveElectrumServerUsecase(
          locator<DeleteCustomServerUsecase>(),
          updateSettings,
          hasActiveOnionServer,
        ),
        updateSettings: updateSettings,
      );
    });
  }
}
