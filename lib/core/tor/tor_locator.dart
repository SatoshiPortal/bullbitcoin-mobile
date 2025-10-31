import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/tor/data/repository/tor_repository.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/tor_status_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';

class TorLocator {
  static Future<void> registerDatasources() async {
    if (!locator.isRegistered<TorDatasource>()) {
      locator.registerSingletonAsync<TorDatasource>(() async {
        return await TorDatasource.init();
      });
    }
    await locator.isReady<TorDatasource>();
  }

  static Future<void> registerRepositories() async {
    locator.registerSingletonWithDependencies<TorRepository>(
      () => TorRepository(locator<TorDatasource>()),
      dependsOn: [TorDatasource],
    );
    await locator.isReady<TorRepository>();
  }

  static void registerUsecases() {
    locator.registerFactory<InitTorUsecase>(
      () => InitTorUsecase(locator<TorRepository>()),
    );

    locator.registerFactory<IsTorRequiredUsecase>(
      () => IsTorRequiredUsecase(walletRepository: locator<WalletRepository>()),
    );

    locator.registerFactory<TorStatusUsecase>(
      () => TorStatusUsecase(locator<TorRepository>()),
    );
  }
}
