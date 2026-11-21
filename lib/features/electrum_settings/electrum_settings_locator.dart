import 'package:electrum/electrum.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:get_it/get_it.dart';

class ElectrumSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<ElectrumSettingsBloc>(
      () => ElectrumSettingsBloc(
        loadElectrumServerDataUsecase: locator<LoadElectrumServerDataUsecase>(),
        addCustomServerUsecase: locator<AddCustomServerUsecase>(),
        setCustomServersPriorityUsecase:
            locator<SetCustomServersPriorityUsecase>(),
        deleteCustomServerUsecase: locator<DeleteCustomServerUsecase>(),
        setAdvancedElectrumOptionsUsecase:
            locator<SetAdvancedElectrumOptionsUsecase>(),
        hasActiveCustomBitcoinOnionServerUsecase:
            locator<HasActiveCustomBitcoinOnionServerUsecase>(),
      ),
    );
  }
}
