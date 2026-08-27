import 'package:async/async.dart';
import 'package:bb_mobile/core/deterministic_wallets/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_recovered_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_frozen_wallet_outpoints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_definitions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_recovery_inventory_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/restore_wallet_definition_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/restore_frozen_wallet_outpoints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_preference_changes_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_catalog_changes_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_utxo_freeze_changes_usecase.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/bullnym_wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/recoverbull_wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_recovery_outcome_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_definitions_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_envelope_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_manifest_import_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_remote_identity_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_recovery_outcome_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/mark_wallet_backup_dirty_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/restore_wallet_backup_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_recovery_blocked_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/sync_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/watch_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_definitions_section.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/labels_bip329_wallet_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_metadata_backup_section_provider.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_metadata_snapshot_composition_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_preferences_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_utxo_freeze_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_section.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_coordinator.dart';
import 'package:get_it/get_it.dart';

abstract final class WalletBackupLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<_WalletBackupGraph>(
      () => _WalletBackupGraph.build(locator),
      dispose: (graph) => graph.dispose(),
    );
    locator.registerLazySingleton<WalletBackupFacade>(
      () => locator<_WalletBackupGraph>().facade,
    );
  }

  static void start(GetIt locator) =>
      locator<_WalletBackupGraph>().coordinator.start();
}

final class _WalletBackupGraph {
  final WalletDefinitionsBackup definitions;
  final WalletMetadataBackup metadata;
  final WalletBackupCoordinator coordinator;
  final WalletBackupFacade facade;

  const _WalletBackupGraph({
    required this.definitions,
    required this.metadata,
    required this.coordinator,
    required this.facade,
  });

  factory _WalletBackupGraph.build(GetIt locator) {
    final definitions = WalletDefinitionsBackupImpl(
      locator<GetWalletDefinitionsUsecase>().execute,
      locator<RestoreWalletDefinitionUsecase>().execute,
      locator<WatchWalletCatalogChangesUsecase>().execute,
    );
    final contributors = <WalletMetadataContributor>[
      LabelsBip329WalletMetadataContributor(locator<LabelsFacade>()),
      WalletUtxoFreezeMetadataContributor(
        locator<GetFrozenWalletOutpointsUsecase>(),
        locator<RestoreFrozenWalletOutpointsUsecase>(),
        locator<WatchWalletUtxoFreezeChangesUsecase>(),
      ),
      WalletPreferencesMetadataContributor(
        locator<GetWalletPreferencesUsecase>(),
        locator<ApplyRecoveredWalletPreferencesUsecase>(),
        locator<WatchWalletPreferenceChangesUsecase>(),
      ),
    ];
    final metadata = WalletMetadataBackupImpl(
      contributors: contributors,
      restoringContributors: contributors
          .cast<WalletMetadataRestoringContributor>(),
      composition: WalletMetadataSnapshotCompositionRepositoryImpl(),
    );
    final encryption = RecoverBullWalletBackupEncryptionRepository();
    final remote = BullnymWalletBackupRemoteRepository(
      locator<BullnymFacade>(),
    );
    final state = DriftWalletBackupStateRepository(locator<SqliteDatabase>());
    final outcomes = WalletBackupRecoveryOutcomeRepositoryImpl(
      locator<KeyValueStorageDatasource<String>>(
        instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
      ),
    );
    final resolveKey = ResolveWalletBackupKeyUsecase(
      locator<GetSettingsUsecase>(),
      locator<GetDefaultSeedUsecase>(),
    );
    final keychainManifest = locator<KeychainManifestFacade>();
    final buildEnvelope = BuildWalletBackupEnvelopeUsecase(
      keychainManifest,
      definitions,
      metadata: metadata,
    );
    final sync = SyncWalletBackupUsecase(
      buildEnvelope: buildEnvelope,
      resolveKey: resolveKey,
      encryption: encryption,
      remote: remote,
      keychainManifest: keychainManifest,
      definitions: definitions,
      metadata: metadata,
    );
    final backupNow = BackupWalletNowUsecase(
      state: state,
      sync: sync.execute,
      nowSecs: () => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    );
    final coordinator = WalletBackupCoordinator(
      manifestChanges: keychainManifest.watchCommittedChanges(),
      metadataChanges: StreamGroup.merge([
        definitions.changes,
        metadata.changes,
      ]),
      syncResults: locator<WatchElectrumSyncResultsUsecase>().execute(),
      publishBackup: backupNow.execute,
      markDirty: MarkWalletBackupDirtyUsecase(state).execute,
    );
    final recover = RecoverWalletBackupUsecase(
      definitions,
      fetchImport: FetchWalletBackupManifestImportUsecase(
        resolveKey: resolveKey,
        remote: remote,
        encryption: encryption,
        keychainManifest: keychainManifest,
        state: state,
      ),
      fetchIdentity: FetchWalletBackupRemoteIdentityUsecase(remote),
      restoreManifest: RestoreWalletBackupManifestUsecase(
        locator<PrepareDeterministicWalletsUsecase>(),
        keychainManifest,
      ),
      setBlocked: SetWalletBackupRecoveryBlockedUsecase(state),
      coordinator: coordinator,
      outcomes: outcomes,
      metadata: metadata,
    );
    final facade = WalletBackupFacade(
      getState: GetWalletBackupStateUsecase(state),
      getContents: GetWalletBackupContentsUsecase(
        locator<GetWalletRecoveryInventoryUsecase>().execute,
        locator<GetWalletPreferencesUsecase>().execute,
        metadata.localInventory,
      ),
      watchState: WatchWalletBackupStateUsecase(state),
      setEnabled: SetWalletBackupEnabledUsecase(state),
      delete: DeleteWalletBackupUsecase(remote: remote, state: state),
      coordinator: coordinator,
      recover: recover,
      getRecoveryOutcome: GetWalletBackupRecoveryOutcomeUsecase(outcomes),
    );
    return _WalletBackupGraph(
      definitions: definitions,
      metadata: metadata,
      coordinator: coordinator,
      facade: facade,
    );
  }

  Future<void> dispose() async {
    await coordinator.dispose();
    await metadata.dispose();
  }
}
