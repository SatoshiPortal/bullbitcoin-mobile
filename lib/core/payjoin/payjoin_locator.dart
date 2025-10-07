import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/check_payjoin_relay_health_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoins_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';

class PayjoinLocator {
  static Future<void> registerDatasources() async {
    locator.registerLazySingleton<LocalPayjoinDatasource>(
      () => LocalPayjoinDatasource(db: locator<SqliteDatabase>()),
    );

    locator.registerLazySingleton<PdkPayjoinDatasource>(
      () => PdkPayjoinDatasource(dio: Dio()),
    );
  }

  static void registerRepositories() {
    // Not a lazy singleton, because it should resume payjoins from the
    // moment the app starts.
    locator.registerSingleton<PayjoinRepository>(
      PayjoinRepositoryImpl(
        localPayjoinDatasource: locator<LocalPayjoinDatasource>(),
        pdkPayjoinDatasource: locator<PdkPayjoinDatasource>(),
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        seedDatasource: locator<SeedDatasource>(),
        blockchainDatasource: locator<BdkBitcoinBlockchainDatasource>(),
        electrumServerStorageDatasource:
            locator<ElectrumServerStorageDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<CheckPayjoinRelayHealthUsecase>(
      () => CheckPayjoinRelayHealthUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
      ),
    );
    locator.registerFactory<BroadcastOriginalTransactionUsecase>(
      () => BroadcastOriginalTransactionUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
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
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );

    locator.registerFactory<GetPayjoinByIdUsecase>(
      () => GetPayjoinByIdUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
      ),
    );

    locator.registerFactory<GetPayjoinsUsecase>(
      () => GetPayjoinsUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<WatchPayjoinUsecase>(
      () =>
          WatchPayjoinUsecase(payjoinRepository: locator<PayjoinRepository>()),
    );
  }
}
