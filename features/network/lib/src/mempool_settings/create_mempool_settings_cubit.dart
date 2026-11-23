import 'package:preferences/preferences.dart';
import 'package:mempool/mempool.dart';

import 'domain/usecases/delete_custom_mempool_server_usecase.dart';
import 'domain/usecases/load_mempool_server_data_usecase.dart';
import 'domain/usecases/set_custom_mempool_server_usecase.dart';
import 'domain/usecases/check_mempool_server_status_usecase.dart';
import 'presentation/mempool_settings_cubit.dart';

MempoolSettingsCubit createMempoolSettingsCubit(
  Mempool mempool,
  Preferences preferences,
) => MempoolSettingsCubit(
  loadDataUsecase: LoadMempoolServerDataUsecase(mempool, preferences),
  setCustomServerUsecase: SetCustomMempoolServerUsecase(mempool, preferences),
  deleteCustomServerUsecase: DeleteCustomMempoolServerUsecase(
    mempool,
    preferences,
  ),
  checkStatusUsecase: CheckMempoolServerStatusUsecase(mempool),
);
