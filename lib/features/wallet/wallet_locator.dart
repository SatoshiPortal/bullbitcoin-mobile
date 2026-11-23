import 'package:secrets/custody.dart';
import 'package:preferences/preferences.dart';
import 'package:receive/receive.dart' show Receive;
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_amount_display_usecase.dart';
import 'package:primitives/primitives.dart';

import 'package:bull_ark/ark_wallet_setup.dart';

import 'domain/usecases/get_default_wallet_network_usecase.dart';
import 'domain/usecases/is_tor_required_usecase.dart';

import 'data/catalog_wallet_secret_references_repository.dart';
import 'domain/repositories/wallet_secret_references_repository.dart';
import 'domain/usecases/load_network_wallet_setup_usecase.dart';
import 'domain/usecases/create_network_wallet_usecase.dart';
import 'presentation/network_wallet_setup_cubit.dart';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter/widgets.dart';

import 'data/payment_notifications.dart';
import 'data/wallet_payment_observer.dart';

import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/foreground_wallet_sync.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';
import 'package:bull_tor/tor.dart';
import 'package:silent/silent.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_scanning_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_wallet_setup_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/refresh_sp_wallet_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_sp_wallet_usecase.dart';
import 'package:swaps/swaps.dart';
import 'package:bb_mobile/features/wallet/data/sync_coordinator.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_stored_wallet_usecase.dart'
    as core;
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_external_tor_proxy_status_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_sync_events_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/retry_swaps_on_refresh_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:bb_mobile/features/wallet/public/default_wallets_facade.dart';
import 'package:wallet_import/setup.dart'
    show
        ProvisionDescriptorWallet,
        ProvisionMnemonicWallet,
        ProvisionXpubWallet;

class WalletLocator {
  static ({
    ProvisionMnemonicWallet mnemonic,
    ProvisionDescriptorWallet descriptor,
    ProvisionXpubWallet xpub,
  })
  importOperations(GetIt services) {
    final repository = services<WalletRepository>();
    return (
      mnemonic: repository.importWallet,
      descriptor: repository.importDescriptor,
      xpub: repository.importWatchOnlyXpub,
    );
  }

  static void setup(GetIt locator, {Receive Function()? receive}) {
    Future<WalletKey> keyFor(String id) =>
        WalletSyncBinding.keyForId(locator<WalletRegistrations>(), id);
    Future<BitcoinSpendStatus> spendStatus(
      String id, {
      String? replacing,
    }) async {
      try {
        return WalletSyncBinding.value<BitcoinSpendStatus>(
          await locator<WalletNativeRuntime>().spendStatus(
            await keyFor(id),
            replacing: replacing,
          ),
        );
      } on Exception {
        return BitcoinSpendStatus.unavailable;
      }
    }

    locator.registerFactory<WalletSecretReferencesRepository>(
      () => CatalogWalletSecretReferencesRepository(
        locator<WalletRegistrations>(),
      ),
    );
    locator.registerFactory<LoadNetworkWalletSetupUsecase>(
      () => LoadNetworkWalletSetupUsecase(
        locator<DeveloperEnvironmentReader>(),
        locator<WalletSecretReferencesRepository>(),
        locator<Secrets>(),
      ),
    );
    locator.registerFactory<CreateNetworkWalletUsecase>(
      () => CreateNetworkWalletUsecase(
        locator<DeveloperEnvironmentReader>(),
        locator<WalletSecretReferencesRepository>(),
        locator<Secrets>(),
        locator<CreateDefaultWalletsUsecase>(),
      ),
    );
    locator.registerFactory<NetworkWalletSetupCubit>(
      () => NetworkWalletSetupCubit(
        locator<LoadNetworkWalletSetupUsecase>(),
        locator<CreateNetworkWalletUsecase>(),
      ),
    );
    locator.registerLazySingleton<BroadcastObservationFollowUp>(
      () => BroadcastObservationFollowUp(
        spendStatus: spendStatus,
        pollWallet: (id, {required isActive}) =>
            locator<SyncCoordinator>().pollWallet(id, isActive: isActive),
      ),
      dispose: (followUp) => followUp.dispose(),
    );
    locator.registerLazySingleton<WalletFacade>(
      () => WalletFacade(
        locator<WalletNativeRuntime>().changes,
        readDefaultWalletNetwork: () =>
            locator<GetDefaultWalletNetworkUsecase>().execute(),
        readTorRequirement: () => locator<IsTorRequiredUsecase>().execute(),
        nextReceiveAddress: receive == null
            ? null
            : (id, {excludedAddresses = const {}}) async =>
                  (await receive().nextUnusedAddress(
                    id,
                    excludedAddresses: excludedAddresses,
                  )).mapErr(
                    (failure) => WalletStorageFailure(failure.logMessage),
                  ),
        spendStatus: spendStatus,
        receiveAddress: receive == null
            ? null
            : (id) async =>
                  (await receive().transferAddress(id))
                      .mapErr((_) => const WalletDiscoveryUnavailableFailure()),
        broadcastSpend: locator<BroadcastObservationFollowUp>().wrap((
          id,
          transaction, {
          required network,
          built,
          owner,
          replacing,
        }) async {
          try {
            return await locator<WalletNativeRuntime>().broadcast(
              await keyFor(id),
              transaction,
              network: network,
              built: built,
              owner: owner,
              replacing: replacing,
            );
          } on WalletSnapshotException catch (error) {
            return Err(error.failure);
          }
        }),
        protectObservedSpend: (id, txid) async {
          try {
            return WalletSyncBinding.value<bool>(
              await locator<WalletNativeRuntime>().protectObservedSpend(
                await keyFor(id),
                txid,
              ),
            );
          } on Exception {
            return false;
          }
        },
        pollWallet: (id, {required isActive}) =>
            locator<SyncCoordinator>().pollWallet(id, isActive: isActive),
        discoverWallet: (id) => locator<SyncCoordinator>().discoverWallet(id),
        syncFinished: locator<ForegroundWalletSync>().finished.map((_) {}),
        syncPassActivity: locator<SyncCoordinator>().syncPassActivity,
        isSyncPassActive: () => locator<SyncCoordinator>().isSyncPassActive,
      ),
    );
    locator.registerFactory<CreateDefaultWalletsUsecase>(
      () => CreateDefaultWalletsUsecase(
        secrets: locator<Secrets>(),
        settingsRepository: locator<ActiveEnvironmentReader>(),
        walletRepository: locator<WalletRepository>(),
        resumeProvisioning: () async => WalletSyncBinding.value(
          await locator<WalletNativeRuntime>().resumeProvisioning(),
        ),
      ),
    );

    locator.registerLazySingleton<WalletNativeRuntime>(
      () => WalletNativeRuntime.open(
        catalog: locator<WalletCatalogPort>(),
        reserved: locator<ReservedAddressPort>(),
        inputReservations: locator<InputReservationPort>(),
        deleteCatalogEntry: (key) async {
          try {
            await locator<WalletRegistrations>().delete(key.id);
            return const Ok(null);
          } on Exception {
            return const Err(SyncStorageFailure());
          }
        },
        sync: locator<ElectrumSync>(),
        documentsDirectory: () async =>
            (await getApplicationDocumentsDirectory()).path,
        freezes: locator<FreezeStorePort>(),
        connections: locator<WalletConnectionPort>(),
        broadcastObservation: locator<BroadcastObservationFollowUp>(),
        fundingReservations:
            locator.isRegistered<SqliteArkFundingReservations>()
            ? locator<SqliteArkFundingReservations>()
            : null,
      ),
    );

    locator.registerLazySingleton<SyncWalletValuesDatasource>(
      () => SyncWalletValuesDatasource(
        load: (key) async => WalletSyncBinding.value(
          await locator<WalletNativeRuntime>().loadWallet(key),
        ),
      ),
    );

    locator.registerLazySingleton<WalletCatalogPort>(
      () => SecretsWalletCatalog.foreground(locator<SecretsInventory>()),
    );
    locator.registerLazySingleton<ElectrumSync>(
      () => ElectrumSync(
        readRevision: (key) => locator<WalletNativeRuntime>().readRevision(key),
        connections: locator<WalletConnectionPort>(),
        collectIncoming: backgroundSyncAvailable,
        onCompletion: backgroundSyncAvailable
            ? locator<WalletPaymentObserver>().recordCompletion
            : null,
        documentsDirectory: () async =>
            (await getApplicationDocumentsDirectory()).path,
      ),
    );
    if (backgroundSyncAvailable) {
      locator.registerLazySingleton<PaymentNotificationStore>(
        () => PaymentNotificationStore(
          () async => (await getApplicationDocumentsDirectory()).path,
          () async => ((await locator<Preferences>().fetch()).fold(
            (value) => value,
            (failure) => throw Exception('Preferences read failed'),
          )).language,
        ),
        dispose: (store) => store.close(),
      );
      locator.registerLazySingleton<WalletPaymentObserver>(
        () => WalletPaymentObserver.foreground(
          locator<PaymentNotificationStore>().open,
          isForeground: () =>
              WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed,
        ),
      );
    }
    locator.registerLazySingleton<ForegroundWalletSync>(
      () => ForegroundWalletSync(
        locator<ElectrumSync>(),
        native: locator<WalletNativeRuntime>(),
      ),
    );
    locator.registerLazySingleton<WalletRepository>(() {
      final sync = locator<ForegroundWalletSync>();
      return WalletRepository(
        native: locator<WalletNativeRuntime>(),
        walletRegistrations: locator<WalletRegistrations>(),
        wallet: locator<WalletNativeRuntime>().wallet,
        walletValuesDatasource: locator<SyncWalletValuesDatasource>(),
        synchronize: sync.synchronize,
        syncStarted: sync.started,
        syncFinished: sync.finished,
      );
    });
    locator.registerFactory<DefaultWalletsFacade>(
      () => DefaultWalletsFacade(locator<CreateDefaultWalletsUsecase>()),
    );
    locator.registerFactory<CheckBackupNeededUsecase>(
      () => CheckBackupNeededUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<ActiveEnvironmentReader>(),
        backupStatus: locator<RecoverBullFacade>().status,
      ),
    );
    // Usecase
    locator.registerFactory<GetUnconfirmedIncomingBalanceUsecase>(
      () =>
          GetUnconfirmedIncomingBalanceUsecase(swapStore: locator<SwapStore>()),
    );
    locator.registerLazySingleton<ParentCustodyAdmissionPort>(
      () => SqliteParentCustodyAdmission(
        directory: () async => (await getApplicationDocumentsDirectory()).path,
        mayCreate: true,
      ),
    );
    locator.registerLazySingleton<SeedReferences>(() {
      final references = SeedReferences(
        locator<WalletRepository>(),
        admission: locator<ParentCustodyAdmissionPort>(),
      );
      // Ark funding holds keep their source seed referenced.
      if (locator.isRegistered<SqliteArkFundingReservations>()) {
        references.register(locator<SqliteArkFundingReservations>());
      } else {
        references.register(
          _UnavailableArkFundingReferences(locator<ArkInstallationState>()),
        );
      }
      return references;
    });
    locator.registerFactory<core.DeleteWalletUsecase>(
      () => core.DeleteWalletUsecase(
        walletRepository: locator<WalletRepository>(),
        swapStore: locator<SwapStore>(),
        seedReferences: locator<SeedReferences>(),
        secrets: locator<Secrets>(),
      ),
    );
    locator.registerFactory<DeleteWalletUsecase>(
      () => DeleteWalletUsecase(
        locator<core.DeleteWalletUsecase>(),
        locator<OrderSwaps>(),
      ),
    );
    locator.registerFactory<GetExternalTorProxyStatusUsecase>(
      () => GetExternalTorProxyStatusUsecase(
        locator<TorProxyPreferencesReader>(),
        locator<Tor>(),
      ),
    );
    locator.registerFactory<CheckSpWalletSetupForWalletUsecase>(
      () => CheckSpWalletSetupForWalletUsecase(silent: locator<Silent>()),
    );
    locator.registerFactory<CheckSpFeatureGateForWalletUsecase>(
      () => CheckSpFeatureGateForWalletUsecase(silent: locator<Silent>()),
    );
    locator.registerFactory<CheckSpScanningForWalletUsecase>(
      () => CheckSpScanningForWalletUsecase(silent: locator<Silent>()),
    );
    locator.registerFactory<RefreshSpWalletForWalletUsecase>(
      () => RefreshSpWalletForWalletUsecase(silent: locator<Silent>()),
    );
    locator.registerFactory<WatchSpWalletUsecase>(
      () => WatchSpWalletUsecase(silent: locator<Silent>()),
    );

    locator.registerFactory<SyncWalletsUsecase>(
      () => SyncWalletsUsecase(locator<SyncCoordinator>()),
    );
    locator.registerFactory<WatchWalletSyncEventsUsecase>(
      () => WatchWalletSyncEventsUsecase(
        watchStarted: locator<WatchStartedWalletSyncsUsecase>(),
        watchFinished: locator<WatchFinishedWalletSyncsUsecase>(),
        watchElectrum: () => locator<ForegroundWalletSync>().results,
      ),
    );
    // Bloc
    locator.registerFactory<WalletBloc>(
      () => WalletBloc(
        watchAmountDisplayUsecase: WatchWalletAmountDisplayUsecase(
          locator<AmountDisplayPreferencesReader>(),
        ),
        watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(
          locator<WalletFacade>(),
        ),
        retrySwapsOnRefreshUsecase: RetrySwapsOnRefreshUsecase(
          locator<SwapActivity>(),
        ),
        checkSpWalletSetupForWalletUsecase:
            locator<CheckSpWalletSetupForWalletUsecase>(),
        checkSpScanningForWalletUsecase:
            locator<CheckSpScanningForWalletUsecase>(),
        refreshSpWalletForWalletUsecase:
            locator<RefreshSpWalletForWalletUsecase>(),
        watchSpWalletUsecase: locator<WatchSpWalletUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        readWalletUsecase: ReadWalletUsecase(locator<WalletRepository>()),
        checkWalletSyncingUsecase: locator<CheckWalletSyncingUsecase>(),
        watchWalletSyncEventsUsecase: locator<WatchWalletSyncEventsUsecase>(),
        syncWalletsUsecase: locator<SyncWalletsUsecase>(),
        getUnconfirmedIncomingBalanceUsecase:
            locator<GetUnconfirmedIncomingBalanceUsecase>(),
        deleteWalletUsecase: locator<DeleteWalletUsecase>(),
        checkBackupNeededUsecase: locator<CheckBackupNeededUsecase>(),
        getExternalTorProxyStatusUsecase:
            locator<GetExternalTorProxyStatusUsecase>(),
        checkSpFeatureGateForWalletUsecase:
            locator<CheckSpFeatureGateForWalletUsecase>(),
      ),
    );
  }
}

/// An opening failure remains an owner; only proven absence has no references.
final class _UnavailableArkFundingReferences implements SeedReferencePort {
  final ArkInstallationState _installation;
  const _UnavailableArkFundingReferences(this._installation);

  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async =>
      await _installation.remainsUnprovisioned()
      ? const Ok({})
      : const Err(SeedReferencesUnavailable());
}
