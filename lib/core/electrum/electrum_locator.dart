import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/check_electrum_status_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_all_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/update_electrum_server_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:hive/hive.dart';

class ElectrumLocator {
  static Future<void> registerDatasources() async {
    final electrumServersBox =
        await Hive.openBox<String>(HiveBoxNameConstants.electrumServers);
    locator.registerLazySingleton<ElectrumServerStorageDatasource>(
      () => ElectrumServerStorageDatasource(
        electrumServerStorage:
            HiveStorageDatasourceImpl<String>(electrumServersBox),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<ElectrumServerRepository>(
      () => ElectrumServerRepositoryImpl(
        electrumServerStorageDatasource:
            locator<ElectrumServerStorageDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerLazySingleton<CheckElectrumStatusUsecase>(
      () => CheckElectrumStatusUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerLazySingleton<UpdateElectrumServerSettingsUsecase>(
      () => UpdateElectrumServerSettingsUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerLazySingleton<GetAllElectrumServersUsecase>(
      () => GetAllElectrumServersUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
  }
}
