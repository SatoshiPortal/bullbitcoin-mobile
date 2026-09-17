import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:get_it/get_it.dart';

/// The read path the silent payments feature still takes to its seed. Every
/// other consumer derives through `secrets`.
class SeedLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<SeedDatasource>(
      () => SeedDatasource(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
    locator.registerLazySingleton<SeedRepository>(
      () => SeedRepository(source: locator<SeedDatasource>()),
    );
    locator.registerFactory<GetDefaultSeedUsecase>(
      () => GetDefaultSeedUsecase(
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
  }
}
