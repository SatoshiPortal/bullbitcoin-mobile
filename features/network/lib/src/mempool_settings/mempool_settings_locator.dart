import 'domain/usecases/delete_custom_mempool_server_usecase.dart';
import 'domain/usecases/load_mempool_server_data_usecase.dart';
import 'domain/usecases/set_custom_mempool_server_usecase.dart';
import 'domain/usecases/check_mempool_server_status_usecase.dart';
import 'presentation/mempool_settings_cubit.dart';

import 'package:get_it/get_it.dart';
import 'package:mempool/mempool.dart';

class MempoolSettingsLocator {
  static void setup(GetIt locator) {
    registerBlocs(locator);
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<MempoolSettingsCubit>(() {
      final mempool = locator<Mempool>();
      return MempoolSettingsCubit(
        loadDataUsecase: LoadMempoolServerDataUsecase(mempool),
        setCustomServerUsecase: SetCustomMempoolServerUsecase(mempool),
        deleteCustomServerUsecase: DeleteCustomMempoolServerUsecase(mempool),
        checkStatusUsecase: CheckMempoolServerStatusUsecase(mempool),
      );
    });
  }
}
