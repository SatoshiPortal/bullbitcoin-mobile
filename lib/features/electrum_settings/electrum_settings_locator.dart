import 'package:bb_mobile/core/electrum/domain/usecases/check_electrum_status_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_all_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/electrum_settings/domain/usecases/get_current_network_usecase.dart';
import 'package:bb_mobile/features/electrum_settings/presentation/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/locator.dart';

class ElectrumSettingsLocator {
  static void setup() {
    // Register the usecases
    locator.registerLazySingleton<GetCurrentNetworkUsecase>(
      () => GetCurrentNetworkUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    // Register the bloc
    locator.registerFactory<ElectrumSettingsBloc>(
      () => ElectrumSettingsBloc(
        getAllElectrumServers: locator<GetAllElectrumServersUsecase>(),
        checkElectrumStatusUsecase: locator<CheckElectrumStatusUsecase>(),
      ),
    );
  }
}
