import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/datasources/lwk_liquid_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/data/repository/liquid_blockchain_repository_impl.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/locator.dart';

class BlockchainLocator {
  static void registerDatasources() {
    locator.registerLazySingleton<BdkBitcoinBlockchainDatasource>(
      () => const BdkBitcoinBlockchainDatasource(),
    );

    locator.registerLazySingleton<LwkLiquidBlockchainDatasource>(
      () => const LwkLiquidBlockchainDatasource(),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<BitcoinBlockchainRepository>(
      () => BitcoinBlockchainRepository(
        blockchainDatasource: locator<BdkBitcoinBlockchainDatasource>(),
        electrumServerStorageDatasource:
            locator<ElectrumServerStorageDatasource>(),
      ),
    );

    locator.registerLazySingleton<LiquidBlockchainRepository>(
      () => LiquidBlockchainRepositoryImpl(
        blockchainDatasource: locator<LwkLiquidBlockchainDatasource>(),
        electrumServerStorageDatasource:
            locator<ElectrumServerStorageDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<BroadcastBitcoinTransactionUsecase>(
      () => BroadcastBitcoinTransactionUsecase(
        bitcoinBlockchainRepository: locator<BitcoinBlockchainRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<BroadcastLiquidTransactionUsecase>(
      () => BroadcastLiquidTransactionUsecase(
        liquidBlockchainRepository: locator<LiquidBlockchainRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
