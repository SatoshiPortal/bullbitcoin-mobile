import 'package:bb_mobile/core/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_custom_servers_priority_usecase.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/electrum_settings/domain/usecases/has_active_custom_bitcoin_onion_server_usecase.dart';
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:get_it/get_it.dart';

class ElectrumSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<HasActiveCustomBitcoinOnionServerUsecase>(
      () => HasActiveCustomBitcoinOnionServerUsecase(
        locator<ElectrumServerRepository>(),
        locator<SettingsRepository>(),
      ),
    );
    locator.registerLazySingleton<ElectrumSettingsFacade>(
      () => ElectrumSettingsFacade(
        hasActiveCustomBitcoinOnionServerUsecase:
            locator<HasActiveCustomBitcoinOnionServerUsecase>(),
      ),
    );
    // Register the bloc
    locator.registerFactory<ElectrumSettingsBloc>(
      () => ElectrumSettingsBloc(
        loadElectrumServerDataUsecase: locator<LoadElectrumServerDataUsecase>(),
        addCustomServerUsecase: locator<AddCustomServerUsecase>(),
        setCustomServersPriorityUsecase:
            locator<SetCustomServersPriorityUsecase>(),
        deleteCustomServerUsecase: locator<DeleteCustomServerUsecase>(),
        setAdvancedElectrumOptionsUsecase:
            locator<SetAdvancedElectrumOptionsUsecase>(),
      ),
    );
  }
}
