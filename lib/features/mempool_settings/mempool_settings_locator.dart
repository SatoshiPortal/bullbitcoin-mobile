import 'package:bb_mobile/core/mempool/application/usecases/delete_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/load_mempool_server_data_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/set_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/update_mempool_settings_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:get_it/get_it.dart';

class MempoolSettingsLocator {
  static void setup(GetIt locator) {
    registerBlocs(locator);
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<MempoolSettingsCubit>(
      () => MempoolSettingsCubit(
        loadDataUsecase: locator<LoadMempoolServerDataUsecase>(),
        setCustomServerUsecase: locator<SetCustomMempoolServerUsecase>(),
        deleteCustomServerUsecase: locator<DeleteCustomMempoolServerUsecase>(),
        updateSettingsUsecase: locator<UpdateMempoolSettingsUsecase>(),
        validator: locator<MempoolServerValidatorPort>(),
      ),
    );
  }
}
