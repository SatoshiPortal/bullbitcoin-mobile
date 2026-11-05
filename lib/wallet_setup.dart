import 'package:bb_mobile/wallet_account_derivation_adapters.dart';
import 'package:bb_mobile/wallet_freeze_adapters.dart';
import 'package:bb_mobile/wallet_sync_connection_adapters.dart';
import 'package:bb_mobile/wallet_signing_adapters.dart';
import 'package:bb_mobile/wallet_freeze_storage_adapters.dart';
import 'package:bb_mobile/wallet_catalog_adapters.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/address_view/data/labeled_wallet_address_repository_impl.dart';
import 'package:bb_mobile/features/address_view/public/address_view_facade.dart';
import 'package:bb_mobile/features/transactions/data/wallet_transaction_repository_impl.dart';
import 'package:bb_mobile/features/coins/data/labeled_wallet_utxo_repository_impl.dart';
import 'package:bb_mobile/features/transactions/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/coins/public/coins_facade.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:notifications/notifications.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show
        DurableWalletSourceOperationCoordinator,
        SqliteWalletSyncMetadataStore,
        WalletCoordinationLogEvent,
        WalletCoordinationLogLevel,
        WalletSourceOperationCoordinator,
        WalletSyncMetadataPort;

class WalletLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<BdkWalletDatasource>(
      () => BdkWalletDatasource(),
    );
    locator.registerLazySingleton<LwkWalletDatasource>(
      () => LwkWalletDatasource(),
    );

    locator.registerLazySingleton<WalletCatalogPort>(
      () => SqliteWalletCatalog(sqlite: locator<SqliteDatabase>()),
    );

    locator.registerLazySingleton<WalletFreezeStorePort>(
      () => SqliteWalletFreezeStore(db: locator<SqliteDatabase>()),
    );
  }

  static Future<void> registerRepositories(GetIt locator) async {
    registerWalletFreezeAdapter(locator);
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final syncMetadata = await SqliteWalletSyncMetadataStore.open(
      databasePath: syncMetadataDatabasePath(documentsDirectory.path),
    );
    locator.registerSingleton<WalletSyncMetadataPort>(
      syncMetadata,
      dispose: (_) => syncMetadata.close(),
    );
    locator.registerLazySingleton<WalletSourceOperationCoordinator>(
      () => DurableWalletSourceOperationCoordinator(
        databasePath: coordinationDatabasePath(documentsDirectory.path),
        logSink: logWalletCoordination,
      ),
    );

    locator.registerLazySingleton<BitcoinWalletRepository>(
      () => BitcoinWalletRepository(
        walletMetadataDatasource: locator<WalletCatalogPort>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        signing: WalletSigningAdapter(
          locator<Secrets>(),
          locator<WalletCatalogPort>(),
          locator<BdkWalletDatasource>(),
        ),
        frozenWalletUtxoDatasource: locator<WalletFreezeStorePort>(),
        coordinator: locator<WalletSourceOperationCoordinator>(),
      ),
    );

    locator.registerLazySingleton<LiquidWalletRepository>(
      () => LiquidWalletRepository(
        walletMetadataDatasource: locator<WalletCatalogPort>(),
        signing: WalletSigningAdapter(
          locator<Secrets>(),
          locator<WalletCatalogPort>(),
          locator<BdkWalletDatasource>(),
        ),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        coordinator: locator<WalletSourceOperationCoordinator>(),
      ),
    );

    locator.registerLazySingleton<WalletRepository>(
      () => WalletRepository(
        walletMetadataDatasource: locator<WalletCatalogPort>(),
        accountDerivation: SecretWalletAccountDerivationAdapter(
          locator<Secrets>(),
        ),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        serversPort: WalletSyncConnectionAdapter(
          locator<ElectrumServersPort>(),
        ),
        coordinator: locator<WalletSourceOperationCoordinator>(),
        syncMetadata: locator<WalletSyncMetadataPort>(),
        paymentObservation: WalletPaymentObservationAdapter(
          () => locator.isRegistered<NotificationsFacade>()
              ? locator<NotificationsFacade>()
              : null,
          isAppVisible: () =>
              WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed,
        ),
      ),
    );

    locator.registerLazySingleton<LabeledWalletUtxoRepository>(
      () => LabeledWalletUtxoRepositoryImpl(
        labelsFacade: locator<LabelsFacade>(),
        wallet: WalletUtxoRepositoryImpl(
          walletMetadataDatasource: locator<WalletCatalogPort>(),
          bdkWalletDatasource: locator<BdkWalletDatasource>(),
          lwkWalletDatasource: locator<LwkWalletDatasource>(),
          frozenWalletUtxoDatasource: locator<WalletFreezeStorePort>(),
          coordinator: locator<WalletSourceOperationCoordinator>(),
        ),
      ),
    );

    locator.registerLazySingleton<LabeledWalletAddressRepository>(
      () => LabeledWalletAddressRepositoryImpl(
        labels: locator<LabelsFacade>(),
        wallet: WalletAddressRepository(
          walletMetadataDatasource: locator<WalletCatalogPort>(),
          bdkWalletDatasource: locator<BdkWalletDatasource>(),
          lwkWalletDatasource: locator<LwkWalletDatasource>(),
          coordinator: locator<WalletSourceOperationCoordinator>(),
        ),
      ),
    );

    locator.registerLazySingleton<WalletTransactionRepository>(
      () => WalletTransactionRepositoryImpl(
        walletMetadataDatasource: locator<WalletCatalogPort>(),
        labelsFacade: locator<LabelsFacade>(),
        reader: WalletTransactionReader(
          snapshots: WalletSnapshotReader(
            paths: _WalletStoragePaths(documentsDirectory.path),
            metadata: locator<WalletSyncMetadataPort>(),
          ),
          bdkWalletTransactionDatasource: locator<BdkWalletDatasource>(),
          lwkWalletTransactionDatasource: locator<LwkWalletDatasource>(),
          serversPort: WalletSyncConnectionAdapter(
            locator<ElectrumServersPort>(),
          ),
          coordinator: locator<WalletSourceOperationCoordinator>(),
        ),
      ),
    );
  }

  static String coordinationDatabasePath(String documentsDirectoryPath) =>
      path.join(
        documentsDirectoryPath,
        'wallet_transaction_sync_coordination.sqlite',
      );

  static String syncMetadataDatabasePath(String documentsDirectoryPath) =>
      path.join(documentsDirectoryPath, 'wallet_sync_metadata.sqlite');

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<CreateDefaultWalletsUsecase>(
      () => CreateDefaultWalletsUsecase(
        secrets: locator<Secrets>(),
        settingsRepository: locator<SettingsRepository>(),
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
    locator.registerFactory<CheckBackupNeededUsecase>(
      () => CheckBackupNeededUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<DeleteStoredWalletUsecase>(
      () => DeleteStoredWalletUsecase(
        walletRepository: locator<WalletRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        secrets: locator<Secrets>(),
      ),
    );
    locator.registerFactory<GetAddressAtIndexUsecase>(
      () => GetAddressAtIndexUsecase(
        walletAddressRepository: locator<LabeledWalletAddressRepository>(),
      ),
    );
    locator.registerLazySingleton<GetWalletUtxosUsecase>(
      () => GetWalletUtxosUsecase(
        utxoRepository: locator<LabeledWalletUtxoRepository>(),
      ),
    );
    locator.registerLazySingleton<CheckLiquidConsolidationUsecase>(
      () => CheckLiquidConsolidationUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<GetReceiveAddressUsecase>(
      () => GetReceiveAddressUsecase(
        walletAddressRepository: locator<LabeledWalletAddressRepository>(),
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
    locator.registerFactory<WatchWalletTransactionByAddressUsecase>(
      () => WatchWalletTransactionByAddressUsecase(
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<WatchWalletTransactionByTxIdUsecase>(
      () => WatchWalletTransactionByTxIdUsecase(
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<CheckWalletStatusUsecase>(
      () => CheckWalletStatusUsecase(
        locator<SettingsRepository>(),
        WalletSyncConnectionAdapter(locator<ElectrumServersPort>()),
        locator<BitcoinWalletRepository>(),
      ),
    );
    locator.registerFactory<SyncWalletUsecase>(
      () => SyncWalletUsecase(walletRepository: locator<WalletRepository>()),
    );
  }
}

/// Persists wallet coordination and source events in the support log.
void logWalletCoordination(WalletCoordinationLogEvent event) {
  switch (event.level) {
    case WalletCoordinationLogLevel.config:
      log.config(event.message);
    case WalletCoordinationLogLevel.fine:
      log.fine(event.message);
    case WalletCoordinationLogLevel.warning:
      log.warning(event.message);
  }
}

final class _WalletStoragePaths implements WalletStoragePathsPort {
  final String _documentsDirectory;

  const _WalletStoragePaths(this._documentsDirectory);

  @override
  Future<WalletStoragePaths> resolve(String walletId) async =>
      WalletStoragePaths.inDocuments(
        documentsDirectory: _documentsDirectory,
        walletId: walletId,
      );
}
