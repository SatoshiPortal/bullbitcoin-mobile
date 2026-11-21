import 'domain/mempool_settings_network.dart';
import 'domain/usecases/delete_custom_mempool_server_usecase.dart';
import 'domain/usecases/load_mempool_server_data_usecase.dart';
import 'domain/usecases/set_custom_mempool_server_usecase.dart';
import 'domain/usecases/check_mempool_server_status_usecase.dart';
import 'presentation/mempool_settings_cubit.dart';

import 'package:get_it/get_it.dart';
import 'package:mempool/mempool.dart';

class MempoolSettingsLocator {
  static void setup(
    GetIt locator, {
    required ReadMempoolEnvironment readEnvironment,
  }) {
    locator.registerFactory<MempoolSettingsCubit>(() {
      final mempool = locator<Mempool>();
      return MempoolSettingsCubit(
        loadDataUsecase: LoadMempoolServerDataUsecase(mempool, readEnvironment),
        setCustomServerUsecase: SetCustomMempoolServerUsecase(
          mempool,
          readEnvironment,
        ),
        deleteCustomServerUsecase: DeleteCustomMempoolServerUsecase(
          mempool,
          readEnvironment,
        ),
        checkStatusUsecase: CheckMempoolServerStatusUsecase(mempool),
      );
    });
  }
}
