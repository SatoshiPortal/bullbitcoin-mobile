import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as domain;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_birthday_checkpoint_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_sync_backend_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/cbf_wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/electrum_wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_birthday_checkpoint_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/unconfirmed_bitcoin_transaction_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_sync_routing_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_transaction_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_utxo_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/cbf_sync_activity_port.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_sync_backend_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/unconfirmed_bitcoin_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_birthday_checkpoint_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/await_cbf_sync_inactive_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/cancel_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_cbf_sync_active_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/record_unconfirmed_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_sync_progress_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:get_it/get_it.dart';

class WalletLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<BdkWalletDatasource>(
      () => BdkWalletDatasource(),
    );
    locator.registerLazySingleton<LwkWalletDatasource>(
      () => LwkWalletDatasource(),
    );
    locator.registerLazySingleton<CbfWalletDatasource>(
      // Resolved lazily, well after every locator's registerRepositories
      // phase has run (see CoreLocator), so domain.SettingsRepository is
      // guaranteed registered by the time this factory actually executes.
      () => CbfWalletDatasource(
        torProxyChangeStream:
            locator<domain.SettingsRepository>().torProxyChangeStream,
        isTorProxyEnabled: () async =>
            (await locator<domain.SettingsRepository>().fetch()).useTorProxy,
      ),
    );

    locator.registerLazySingleton<WalletMetadataDatasource>(
      () => WalletMetadataDatasource(sqlite: locator<SqliteDatabase>()),
    );

    locator.registerLazySingleton<FrozenWalletUtxoDatasource>(
      () => FrozenWalletUtxoDatasource(db: locator<SqliteDatabase>()),
    );

    // Resolved lazily, well after MempoolLocator.registerUsecases has run
    // (see CoreLocator) — same reasoning as CbfWalletDatasource above:
    // nothing here calls locator<GetActiveMempoolServerUsecase>() until
    // this datasource is actually resolved, by which point every locator's
    // registerUsecases phase has completed.
    locator.registerLazySingleton<WalletBirthdayCheckpointDatasource>(
      () => WalletBirthdayCheckpointDatasource(
        getActiveMempoolServerUsecase: locator<GetActiveMempoolServerUsecase>(),
      ),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<BitcoinWalletRepository>(
      () => BitcoinWalletRepository(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        seedDatasource: locator<SeedDatasource>(),
      ),
    );

    locator.registerLazySingleton<LiquidWalletRepository>(
      () => LiquidWalletRepository(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        seedDatasource: locator<SeedDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
      ),
    );

    locator.registerLazySingleton<WalletRepository>(
      () => WalletRepository(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        cbfWalletDatasource: locator<CbfWalletDatasource>(),
        serversPort: locator<ElectrumServersPort>(),
        cbfSyncActivityPort: locator<CbfSyncActivityPort>(),
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

    locator.registerLazySingleton<WalletAddressRepository>(
      () => WalletAddressRepository(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        labelsFacade: locator<LabelsFacade>(),
      ),
    );

    locator.registerLazySingleton<WalletTransactionRepository>(
      () => WalletTransactionRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        labelsFacade: locator<LabelsFacade>(),
        bdkWalletTransactionDatasource: locator<BdkWalletDatasource>(),
        lwkWalletTransactionDatasource: locator<LwkWalletDatasource>(),
        serversPort: locator<ElectrumServersPort>(),
      ),
    );

    // Typed sync contract (see docs/compact-block-filters-pr-roadmap.md PR 3
    // and PR 4). Electrum adapts the existing sync path unchanged; CBF is a
    // foreground, developer-gated backend. WalletSyncRepository is the
    // router both are reached through — see WalletSyncRoutingRepository.
    locator.registerLazySingleton<ElectrumWalletSyncRepository>(
      () => ElectrumWalletSyncRepository(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerLazySingleton<CbfWalletSyncRepository>(
      () => CbfWalletSyncRepository(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        cbfWalletDatasource: locator<CbfWalletDatasource>(),
      ),
    );

    // CbfWalletDatasource is the canonical CbfSyncActivityPort
    // implementation — see that port's class doc for why. Resolved to the
    // same CbfWalletDatasource singleton registered above, not
    // CbfWalletSyncRepository or the app-wide routing WalletSyncRepository
    // below (WalletRepository depends on this port, and both of those are
    // built on top of WalletRepository).
    locator.registerLazySingleton<CbfSyncActivityPort>(
      () => locator<CbfWalletDatasource>(),
    );
    locator.registerLazySingleton<WalletSyncRepository>(
      () => WalletSyncRoutingRepository(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        settingsRepository: locator<domain.SettingsRepository>(),
        checkCompactBlockFiltersAvailableUsecase:
            locator<CheckCompactBlockFiltersAvailableUsecase>(),
        electrumWalletSyncRepository: locator<ElectrumWalletSyncRepository>(),
        cbfWalletSyncRepository: locator<CbfWalletSyncRepository>(),
      ),
    );

    locator.registerLazySingleton<BitcoinSyncBackendRepository>(
      () => BitcoinSyncBackendRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
      ),
    );

    locator.registerLazySingleton<WalletBirthdayCheckpointRepository>(
      () => WalletBirthdayCheckpointRepositoryImpl(
        datasource: locator<WalletBirthdayCheckpointDatasource>(),
      ),
    );

    // Registered before PayjoinLocator.registerRepositories in
    // CoreLocator.registerRepositories (PayjoinRepositoryImpl is an eager
    // registerSingleton and depends on this).
    locator.registerLazySingleton<UnconfirmedBitcoinTransactionRepository>(
      () => UnconfirmedBitcoinTransactionRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        cbfWalletDatasource: locator<CbfWalletDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    // The single source of truth for the CBF developer/beta gate — see the
    // class doc. Registered once here; every call site that used to
    // duplicate its own kDebugMode/dev-mode/Tor check now injects this
    // instead.
    locator.registerFactory<CheckCompactBlockFiltersAvailableUsecase>(
      () => CheckCompactBlockFiltersAvailableUsecase(
        settingsRepository: locator<domain.SettingsRepository>(),
      ),
    );
    locator.registerFactory<CreateDefaultWalletsUsecase>(
      () => CreateDefaultWalletsUsecase(
        seedRepository: locator<SeedRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        mnemonicGenerator: locator<MnemonicGenerator>(),
        walletRepository: locator<WalletRepository>(),
        checkCompactBlockFiltersAvailableUsecase:
            locator<CheckCompactBlockFiltersAvailableUsecase>(),
        resolveWalletBirthdayCheckpointUsecase:
            locator<ResolveWalletBirthdayCheckpointUsecase>(),
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

    locator.registerFactory<DeleteWalletUsecase>(
      () => DeleteWalletUsecase(
        walletRepository: locator<WalletRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
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
    locator.registerFactory<GetReceiveAddressUsecase>(
      () => GetReceiveAddressUsecase(
        walletAddressRepository: locator<WalletAddressRepository>(),
        awaitCbfSyncInactiveUsecase: locator<AwaitCbfSyncInactiveUsecase>(),
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
    locator.registerFactory<WatchWalletTransactionByTxIdUsecase>(
      () => WatchWalletTransactionByTxIdUsecase(
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<CheckWalletStatusUsecase>(
      () => CheckWalletStatusUsecase(
        locator<SettingsRepository>(),
        locator<ElectrumServersPort>(),
        locator<BitcoinWalletRepository>(),
      ),
    );
    // See sync_wallet_usecase.dart's class doc: SyncCoordinator's foreground
    // calls (default allowCompactBlockFilters: true) route through
    // WalletSyncRepository, so a wizard-created CBF wallet actually syncs
    // with CBF; background tasks explicitly pass
    // allowCompactBlockFilters: false to force the legacy Electrum-only
    // path.
    locator.registerFactory<SyncWalletUsecase>(
      () => SyncWalletUsecase(
        walletSyncRepository: locator<WalletSyncRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<StartWalletSyncUsecase>(
      () => StartWalletSyncUsecase(
        walletSyncRepository: locator<WalletSyncRepository>(),
      ),
    );
    locator.registerFactory<WatchWalletSyncProgressUsecase>(
      () => WatchWalletSyncProgressUsecase(
        walletSyncRepository: locator<WalletSyncRepository>(),
      ),
    );
    locator.registerFactory<CancelWalletSyncUsecase>(
      () => CancelWalletSyncUsecase(
        walletSyncRepository: locator<WalletSyncRepository>(),
      ),
    );
    locator.registerFactory<CheckCbfSyncActiveUsecase>(
      () => CheckCbfSyncActiveUsecase(
        cbfSyncActivityPort: locator<CbfSyncActivityPort>(),
      ),
    );
    locator.registerFactory<AwaitCbfSyncInactiveUsecase>(
      () => AwaitCbfSyncInactiveUsecase(
        cbfSyncActivityPort: locator<CbfSyncActivityPort>(),
      ),
    );
    locator.registerFactory<GetBitcoinSyncBackendUsecase>(
      () => GetBitcoinSyncBackendUsecase(
        bitcoinSyncBackendRepository: locator<BitcoinSyncBackendRepository>(),
      ),
    );
    locator.registerFactory<SetBitcoinSyncBackendUsecase>(
      () => SetBitcoinSyncBackendUsecase(
        bitcoinSyncBackendRepository: locator<BitcoinSyncBackendRepository>(),
      ),
    );
    locator.registerFactory<RecordUnconfirmedBitcoinTransactionUsecase>(
      () => RecordUnconfirmedBitcoinTransactionUsecase(
        unconfirmedBitcoinTransactionRepository:
            locator<UnconfirmedBitcoinTransactionRepository>(),
      ),
    );
    locator.registerFactory<ResolveWalletBirthdayCheckpointUsecase>(
      () => ResolveWalletBirthdayCheckpointUsecase(
        walletBirthdayCheckpointRepository:
            locator<WalletBirthdayCheckpointRepository>(),
      ),
    );
  }
}
