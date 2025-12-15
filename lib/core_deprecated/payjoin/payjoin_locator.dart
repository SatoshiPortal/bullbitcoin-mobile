import 'package:bb_mobile/core_deprecated/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core_deprecated/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core_deprecated/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core_deprecated/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core_deprecated/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core_deprecated/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/usecases/check_payjoin_relay_health_usecase.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/usecases/get_payjoins_usecase.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core_deprecated/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class PayjoinLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<LocalPayjoinDatasource>(
      () => LocalPayjoinDatasource(db: locator<SqliteDatabase>()),
    );

    locator.registerLazySingleton<PdkPayjoinDatasource>(
      () => PdkPayjoinDatasource(dio: Dio()),
    );
  }

  static void registerRepositories(GetIt locator) {
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
        electrumSettingsStorageDatasource:
            locator<ElectrumSettingsStorageDatasource>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
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
