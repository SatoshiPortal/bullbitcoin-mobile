import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/payjoin/data/services/payjoin_watcher_service_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utxo/domain/repositories/utxo_repository.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

class PayjoinLocator {
  static Future<void> registerDatasources() async {
    final pdkPayjoinsBox =
        await Hive.openBox<String>(HiveBoxNameConstants.pdkPayjoins);
    locator.registerLazySingleton<PayjoinDatasource>(
      () => PayjoinDatasource(
        dio: Dio(),
        storage: HiveStorageDatasourceImpl<String>(pdkPayjoinsBox),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<PayjoinRepository>(
      () => PayjoinRepositoryImpl(
        payjoinDatasource: locator<PayjoinDatasource>(),
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        seedDatasource: locator<SeedDatasource>(),
        blockchainDatasource: locator<BdkBitcoinBlockchainDatasource>(),
        electrumServerStorageDatasource:
            locator<ElectrumServerStorageDatasource>(),
      ),
    );
  }

  static void registerServices() {
    locator.registerLazySingleton<PayjoinWatcherService>(
      () => PayjoinWatcherServiceImpl(
        payjoinRepository: locator<PayjoinRepository>(),
        walletRepository: locator<WalletRepository>(),
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
        utxoRepository: locator<UtxoRepository>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<BroadcastOriginalTransactionUsecase>(
      () => BroadcastOriginalTransactionUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );

    locator.registerFactory<ReceiveWithPayjoinUsecase>(
      () => ReceiveWithPayjoinUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<SendWithPayjoinUsecase>(
      () => SendWithPayjoinUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
      ),
    );

    locator.registerFactory<WatchPayjoinUsecase>(
      () => WatchPayjoinUsecase(
        payjoinWatcherService: locator<PayjoinWatcherService>(),
      ),
    );
  }
}
