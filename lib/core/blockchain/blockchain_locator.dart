import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/transactions/data/datasources/send_timestamp_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/datasources/lwk_liquid_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/data/repository/liquid_blockchain_repository_impl.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:get_it/get_it.dart';

class BlockchainLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<BdkBitcoinBlockchainDatasource>(
      () => const BdkBitcoinBlockchainDatasource(),
    );

    locator.registerLazySingleton<LwkLiquidBlockchainDatasource>(
      () => const LwkLiquidBlockchainDatasource(),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<BitcoinBlockchainRepository>(
      () => BitcoinBlockchainRepository(
        blockchainDatasource: locator<BdkBitcoinBlockchainDatasource>(),
        serversPort: locator<ElectrumServersPort>(),
      ),
    );

    locator.registerLazySingleton<LiquidBlockchainRepository>(
      () => LiquidBlockchainRepositoryImpl(
        blockchainDatasource: locator<LwkLiquidBlockchainDatasource>(),
        serversPort: locator<ElectrumServersPort>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    if (!locator.isRegistered<SendTimestampDatasource>()) {
      locator.registerLazySingleton<SendTimestampDatasource>(
        () => SendTimestampDatasource(db: locator<SqliteDatabase>()),
      );
    }

    locator.registerFactory<BroadcastBitcoinTransactionUsecase>(
      () => BroadcastBitcoinTransactionUsecase(
        bitcoinBlockchainRepository: locator<BitcoinBlockchainRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        sendTimestampDatasource: locator<SendTimestampDatasource>(),
      ),
    );

    locator.registerFactory<BroadcastLiquidTransactionUsecase>(
      () => BroadcastLiquidTransactionUsecase(
        liquidBlockchainRepository: locator<LiquidBlockchainRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        sendTimestampDatasource: locator<SendTimestampDatasource>(),
      ),
    );
  }
}
