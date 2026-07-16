import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/sync/watch_successful_foreground_syncs_usecase.dart';
import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_recovered_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_frozen_wallet_outpoints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/restore_frozen_wallet_outpoints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_preference_changes_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_utxo_freeze_changes_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/bullnym_wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/drift_wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/labels_bip329_wallet_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/local_wallet_metadata_key_material_adapter.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_key_deriver.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_composition_repository_impl.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_cryptor_impl.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_preferences_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_utxo_freeze_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_snapshot_composition_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_snapshot_cryptor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/apply_wallet_metadata_recovery_plan_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/build_wallet_metadata_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/delete_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/fetch_current_wallet_metadata_recovery_plan_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/fetch_wallet_metadata_recovery_plan_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/get_wallet_metadata_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/mark_wallet_metadata_backup_dirty_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/publish_current_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/publish_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/set_wallet_metadata_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_key_material_port.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_publication_guard.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/watchers/wallet_metadata_backup_coordinator.dart';
import 'package:get_it/get_it.dart';

final class WalletMetadataBackupLocator {
  const WalletMetadataBackupLocator._();

  static void setup(GetIt locator) {
    locator.registerLazySingleton<LabelsBip329WalletMetadataContributor>(
      () => LabelsBip329WalletMetadataContributor(locator<LabelsFacade>()),
    );
    locator.registerLazySingleton<WalletUtxoFreezeMetadataContributor>(
      () => WalletUtxoFreezeMetadataContributor(
        locator<GetFrozenWalletOutpointsUsecase>(),
        locator<RestoreFrozenWalletOutpointsUsecase>(),
        locator<WatchWalletUtxoFreezeChangesUsecase>(),
      ),
    );
    locator.registerLazySingleton<WalletPreferencesMetadataContributor>(
      () => WalletPreferencesMetadataContributor(
        locator<GetWalletPreferencesUsecase>(),
        locator<ApplyRecoveredWalletPreferencesUsecase>(),
        locator<WatchWalletPreferenceChangesUsecase>(),
      ),
    );
    locator.registerLazySingleton<WalletMetadataPublicationGuard>(
      WalletMetadataPublicationGuard.new,
    );
    locator.registerLazySingleton<WalletMetadataKeyMaterialPort>(
      () => LocalWalletMetadataKeyMaterialAdapter(
        getSettings: locator<GetSettingsUsecase>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerLazySingleton<WalletMetadataBackupStateRepository>(
      () => DriftWalletMetadataBackupStateRepository(locator<SqliteDatabase>()),
    );
    locator.registerLazySingleton<WalletMetadataSnapshotCryptor>(
      () => WalletMetadataSnapshotCryptorImpl(
        keyDeriver: WalletMetadataKeyDeriver(
          registry: locator<Bip85RegistryFacade>(),
        ),
      ),
    );
    locator.registerLazySingleton<WalletMetadataSnapshotCompositionRepository>(
      WalletMetadataSnapshotCompositionRepositoryImpl.new,
    );
    locator.registerLazySingleton<WalletMetadataRemoteRepository>(
      () => BullnymWalletMetadataRemoteRepository(
        bullnym: locator<BullnymFacade>(),
        snapshots: locator<WalletMetadataSnapshotCryptor>(),
        identity: locator<NostrIdentityFacade>(),
      ),
    );
    locator.registerFactory<BuildWalletMetadataSnapshotUsecase>(
      () => BuildWalletMetadataSnapshotUsecase(
        locator<WalletMetadataSnapshotCryptor>(),
      ),
    );
    locator.registerFactory<GetWalletMetadataBackupStateUsecase>(
      () => GetWalletMetadataBackupStateUsecase(
        locator<WalletMetadataBackupStateRepository>(),
      ),
    );
    locator.registerFactory<SetWalletMetadataBackupEnabledUsecase>(
      () => SetWalletMetadataBackupEnabledUsecase(
        locator<WalletMetadataBackupStateRepository>(),
      ),
    );
    locator.registerFactory<MarkWalletMetadataBackupDirtyUsecase>(
      () => MarkWalletMetadataBackupDirtyUsecase(
        locator<WalletMetadataBackupStateRepository>(),
      ),
    );
    locator.registerFactory<PublishWalletMetadataBackupUsecase>(
      () => PublishWalletMetadataBackupUsecase(
        stateRepository: locator<WalletMetadataBackupStateRepository>(),
        remoteRepository: locator<WalletMetadataRemoteRepository>(),
        compositionRepository:
            locator<WalletMetadataSnapshotCompositionRepository>(),
        snapshotCryptor: locator<WalletMetadataSnapshotCryptor>(),
        contributors: _contributors(locator),
        clock: locator<Clock>(),
      ),
    );
    locator.registerFactory<PublishCurrentWalletMetadataBackupUsecase>(
      () => PublishCurrentWalletMetadataBackupUsecase(
        stateRepository: locator<WalletMetadataBackupStateRepository>(),
        keyMaterialPort: locator<WalletMetadataKeyMaterialPort>(),
        publish: locator<PublishWalletMetadataBackupUsecase>(),
      ),
    );
    locator.registerFactory<DeleteWalletMetadataBackupUsecase>(
      () => DeleteWalletMetadataBackupUsecase(
        stateRepository: locator<WalletMetadataBackupStateRepository>(),
        remoteRepository: locator<WalletMetadataRemoteRepository>(),
        keyMaterialPort: locator<WalletMetadataKeyMaterialPort>(),
      ),
    );
    locator.registerFactory<FetchWalletMetadataRecoveryPlanUsecase>(
      () => FetchWalletMetadataRecoveryPlanUsecase(
        stateRepository: locator<WalletMetadataBackupStateRepository>(),
        remoteRepository: locator<WalletMetadataRemoteRepository>(),
        contributors: _contributors(locator),
        clock: locator<Clock>(),
      ),
    );
    locator.registerFactory<FetchCurrentWalletMetadataRecoveryPlanUsecase>(
      () => FetchCurrentWalletMetadataRecoveryPlanUsecase(
        keyMaterial: locator<WalletMetadataKeyMaterialPort>(),
        fetch: locator<FetchWalletMetadataRecoveryPlanUsecase>(),
      ),
    );
    locator.registerFactory<ApplyWalletMetadataRecoveryPlanUsecase>(
      () => ApplyWalletMetadataRecoveryPlanUsecase(
        locator<WalletMetadataKeyMaterialPort>(),
        stateRepository: locator<WalletMetadataBackupStateRepository>(),
        remoteRepository: locator<WalletMetadataRemoteRepository>(),
        contributors: _restoringContributors(locator),
        publicationGuard: locator<WalletMetadataPublicationGuard>(),
        clock: locator<Clock>(),
      ),
    );
    locator.registerLazySingleton<WalletMetadataBackupCoordinator>(
      () => WalletMetadataBackupCoordinator(
        markDirty: locator<MarkWalletMetadataBackupDirtyUsecase>(),
        publishCurrent: () =>
            locator<PublishCurrentWalletMetadataBackupUsecase>().execute(),
        guard: locator<WalletMetadataPublicationGuard>(),
        sources: () => _changeSources(locator),
        successfulSyncs: () =>
            locator<WatchSuccessfulForegroundSyncsUsecase>().execute(),
      ),
      dispose: (coordinator) => coordinator.dispose(),
    );
    locator.registerLazySingleton<WalletMetadataBackupFacade>(
      () => WalletMetadataBackupFacade(
        locator<GetWalletMetadataBackupStateUsecase>(),
        locator<SetWalletMetadataBackupEnabledUsecase>(),
        locator<MarkWalletMetadataBackupDirtyUsecase>(),
        locator<DeleteWalletMetadataBackupUsecase>(),
        locator<WalletMetadataBackupCoordinator>(),
        () =>
            locator<FetchCurrentWalletMetadataRecoveryPlanUsecase>().execute(),
        ({required plan, required createdWalletRefs}) =>
            locator<ApplyWalletMetadataRecoveryPlanUsecase>().execute(
              plan: plan,
              createdWalletRefs: createdWalletRefs,
            ),
      ),
    );
  }

  static Future<void> start(GetIt locator) =>
      locator<WalletMetadataBackupCoordinator>().start();

  static List<WalletMetadataContributor> _contributors(GetIt locator) => [
    locator<LabelsBip329WalletMetadataContributor>(),
    locator<WalletUtxoFreezeMetadataContributor>(),
    locator<WalletPreferencesMetadataContributor>(),
  ];

  static List<WalletMetadataRestoringContributor> _restoringContributors(
    GetIt locator,
  ) => [
    locator<LabelsBip329WalletMetadataContributor>(),
    locator<WalletUtxoFreezeMetadataContributor>(),
    locator<WalletPreferencesMetadataContributor>(),
  ];

  static List<WalletMetadataChangeSource> _changeSources(GetIt locator) => [
    locator<LabelsBip329WalletMetadataContributor>(),
    locator<WalletUtxoFreezeMetadataContributor>(),
    locator<WalletPreferencesMetadataContributor>(),
  ];
}
