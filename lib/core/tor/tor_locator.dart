import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/tor/data/repository/tor_repository.dart';
import 'package:bb_mobile/core/tor/domain/usecases/check_for_tor_initialization_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/initialize_tor_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';

class TorLocator {
  static Future<void> registerDatasources() async {
    if (!locator.isRegistered<TorDatasource>()) {
      // Register TorDatasource as a singleton async
      // This ensures Tor is properly initialized before it's used
      locator.registerSingletonAsync<TorDatasource>(() async {
        final tor = await TorDatasource.init();
        return tor;
      });
    }
    await locator.isReady<TorDatasource>();
  }

  static Future<void> registerRepositories() async {
    locator.registerSingletonWithDependencies<TorRepository>(
      () => TorRepository(locator<TorDatasource>()),
      dependsOn: [TorDatasource],
    );
    // Wait for Tor dependencies to be ready
    // Register TorRepository after TorDatasource is registered
    // Use waitFor to ensure TorDatasource is ready before TorRepository is created
    await locator.isReady<TorRepository>();
  }

  static void registerUsecases() {
    locator.registerFactory<InitializeTorUsecase>(
      () => InitializeTorUsecase(locator<TorRepository>()),
    );

    locator.registerFactory<CheckTorRequiredOnStartupUsecase>(
      () => CheckTorRequiredOnStartupUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
  }
}
