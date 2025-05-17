import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/impl/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/impl/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_transaction_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_utxo_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_bip85_derived_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_use_case.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_used_receive_addresses_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/locator.dart';

class WalletLocator {
  static Future<void> registerDatasourceres() async {
    locator.registerLazySingleton<BdkWalletDatasource>(
      () => BdkWalletDatasource(),
    );
    locator.registerLazySingleton<LwkWalletDatasource>(
      () => LwkWalletDatasource(),
    );

    locator.registerLazySingleton<WalletMetadataDatasource>(
      () =>
          WalletMetadataDatasource(sqliteDatasource: locator<SqliteDatabase>()),
    );

    locator.registerLazySingleton<FrozenWalletUtxoDatasource>(
      () => FrozenWalletUtxoDatasource(),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<BitcoinWalletRepository>(
      () => BitcoinWalletRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        seedDatasource: locator<SeedDatasource>(),
      ),
    );

    locator.registerLazySingleton<LiquidWalletRepository>(
      () => LiquidWalletRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        seedDatasource: locator<SeedDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
      ),
    );

    locator.registerLazySingleton<WalletRepository>(
      () => WalletRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        electrumServerStorageDatasource:
            locator<ElectrumServerStorageDatasource>(),
      ),
    );

    locator.registerLazySingleton<WalletUtxoRepository>(
      () => WalletUtxoRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        frozenWalletUtxoDatasource: locator<FrozenWalletUtxoDatasource>(),
        labelDatasource: locator<LabelDatasource>(),
      ),
    );

    locator.registerLazySingleton<WalletAddressRepository>(
      () => WalletAddressRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
      ),
    );

    locator.registerLazySingleton<WalletTransactionRepository>(
      () => WalletTransactionRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        labelDatasource: locator<LabelDatasource>(),
        bdkWalletTransactionDatasource: locator<BdkWalletDatasource>(),
        lwkWalletTransactionDatasource: locator<LwkWalletDatasource>(),
        electrumServerStorage: locator<ElectrumServerStorageDatasource>(),
        payjoinDatasource: locator<LocalPayjoinDatasource>(),
        swapDatasource: locator<BoltzStorageDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<CreateDefaultWalletsUsecase>(
      () => CreateDefaultWalletsUsecase(
        seedRepository: locator<SeedRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        mnemonicGenerator: locator<MnemonicGenerator>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<GetWalletUsecase>(
      () => GetWalletUsecase(walletRepository: locator<WalletRepository>()),
    );
    locator.registerFactory<GetWalletsUsecase>(
      () => GetWalletsUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<WatchStartedWalletSyncsUsecase>(
      () => WatchStartedWalletSyncsUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<WatchFinishedWalletSyncsUsecase>(
      () => WatchFinishedWalletSyncsUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<CheckWalletSyncingUsecase>(
      () => CheckWalletSyncingUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerLazySingleton<GetWalletUtxosUsecase>(
      () => GetWalletUtxosUsecase(
        utxoRepository: locator<WalletUtxoRepository>(),
      ),
    );
    locator.registerFactory<GetReceiveAddressUsecase>(
      () => GetReceiveAddressUsecase(
        walletAddressRepository: locator<WalletAddressRepository>(),
      ),
    );
    locator.registerFactory<GetUsedReceiveAddressesUsecase>(
      () => GetUsedReceiveAddressesUsecase(
        walletAddressRepository: locator<WalletAddressRepository>(),
      ),
    );
    locator.registerFactory<GetWalletTransactionsUsecase>(
      () => GetWalletTransactionsUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
      ),
    );
    locator.registerFactory<WatchWalletTransactionByAddressUsecase>(
      () => WatchWalletTransactionByAddressUsecase(
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<CreateBip85DerivedWalletUseCase>(
      () => CreateBip85DerivedWalletUseCase(
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
