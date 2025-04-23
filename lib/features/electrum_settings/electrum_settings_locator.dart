import 'package:bb_mobile/core/electrum/domain/usecases/check_electrum_status_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_all_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/update_electrum_server_settings_usecase.dart';

import 'package:bb_mobile/features/electrum_settings/presentation/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/locator.dart';

class ElectrumSettingsLocator {
  static void setup() {
    // Register the bloc
    locator.registerFactory<ElectrumSettingsBloc>(
      () => ElectrumSettingsBloc(
        getAllElectrumServers: locator<GetAllElectrumServersUsecase>(),
        checkElectrumStatusUsecase: locator<CheckElectrumStatusUsecase>(),
        updateElectrumServerSettings:
            locator<UpdateElectrumServerSettingsUsecase>(),
      ),
    );
  }
}
