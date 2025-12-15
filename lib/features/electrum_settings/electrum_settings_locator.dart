import 'package:bb_mobile/core_deprecated/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/set_custom_servers_priority_usecase.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/locator.dart';

class ElectrumSettingsLocator {
  static void setup() {
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
