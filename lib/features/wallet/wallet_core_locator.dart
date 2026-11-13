import 'data/wallet_native_runtime.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_utxo_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:get_it/get_it.dart';

class WalletLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<WalletMetadataDatasource>(
      () => WalletMetadataDatasource(sqlite: locator<SqliteDatabase>()),
    );

    locator.registerLazySingleton<FrozenWalletUtxoDatasource>(
      () => FrozenWalletUtxoDatasource(db: locator<SqliteDatabase>()),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<BitcoinWalletRepository>(
      () => BitcoinWalletRepository(
        requireSpend: locator<WalletNativeRuntime>().requireSpend,
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        secrets: locator<Secrets>(),
        frozenWalletUtxoDatasource: locator<FrozenWalletUtxoDatasource>(),
      ),
    );

    locator.registerLazySingleton<LiquidWalletRepository>(
      () => LiquidWalletRepository(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        secrets: locator<Secrets>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        frozenWalletUtxoDatasource: locator<FrozenWalletUtxoDatasource>(),
      ),
    );

    locator.registerLazySingleton<WalletUtxoRepository>(
      () => WalletUtxoRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        frozenWalletUtxoDatasource: locator<FrozenWalletUtxoDatasource>(),
        labelsFacade: locator<LabelsFacade>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
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
    locator.registerFactory<WatchElectrumSyncResultsUsecase>(
      () => WatchElectrumSyncResultsUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<CheckWalletSyncingUsecase>(
      () => CheckWalletSyncingUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );

    locator.registerFactory<GetAddressAtIndexUsecase>(
      () => GetAddressAtIndexUsecase(
        walletAddressRepository: locator<WalletAddressRepository>(),
      ),
    );
    locator.registerLazySingleton<GetWalletUtxosUsecase>(
      () => GetWalletUtxosUsecase(
        utxoRepository: locator<WalletUtxoRepository>(),
      ),
    );
    locator.registerLazySingleton<CheckLiquidConsolidationUsecase>(
      () => CheckLiquidConsolidationUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<GetReceiveAddressUsecase>(
      () => GetReceiveAddressUsecase(
        walletAddressRepository: locator<WalletAddressRepository>(),
      ),
    );
    locator.registerFactory<GetWalletTransactionsUsecase>(
      () => GetWalletTransactionsUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
      ),
    );
    locator.registerFactory<GetWalletTransactionUsecase>(
      () => GetWalletTransactionUsecase(
        walletTransactionRepository: locator<WalletTransactionRepository>(),
      ),
    );
    locator.registerFactory<SyncWalletUsecase>(
      () => SyncWalletUsecase(walletRepository: locator<WalletRepository>()),
    );
  }
}
