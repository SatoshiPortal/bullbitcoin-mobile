import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/features/fees/data/fees_repository_impl.dart';
import 'package:bb_mobile/features/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:preferences/preferences.dart';
import 'package:get_it/get_it.dart';

class FeesLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<FeesDatasource>(() => FeesDatasource());
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<FeesRepository>(
      () => FeesRepositoryImpl(
        feesDatasource: locator<FeesDatasource>(),
        mempool: locator(),
        electrumServers: locator(),
      ),
    );
  }

  static void registerUseCases(GetIt locator) {
    locator.registerFactory<GetNetworkFeesUsecase>(
      () => GetNetworkFeesUsecase(
        feesRepository: locator<FeesRepository>(),
        settingsRepository: locator<Preferences>(),
      ),
    );
  }

  static Future<void> checkBitcoinFees(
    GetIt locator,
    BitcoinNetwork network,
  ) async {
    await locator<FeesRepository>().getNetworkFees(
      network: Network.fromEnvironment(
        environment: network.env,
        isLiquid: false,
      ),
    );
  }
}
