import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_recovered_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_frozen_wallet_outpoints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_definitions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/restore_wallet_definition_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/restore_frozen_wallet_outpoints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_catalog_changes_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_preference_changes_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_utxo_freeze_changes_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/metadata_backup_http_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_backup/data/recoverbull_wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_definitions_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_export_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/compare_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/decode_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_recovery_inventory_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/refresh_wallet_recovery_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/restore_wallet_backup_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_server_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/store_selected_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/register_wallet_backup_recovery_material_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/watch_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/wallet_backup_remote_usecases.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_job_runner.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_metadata_backup_section_provider.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_portable_settings_backup.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_triggers.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'dart:async';

import 'package:async/async.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

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

  static void start(GetIt locator) {
    final graph = locator<_WalletBackupGraph>();
    // Registration needs the default seed, which does not exist before the
    // first wallet. Publication registers again when backup is enabled, so a
    // failure here is only worth logging.
    unawaited(
      graph.registerRecoveryMaterial.execute().then((result) {
        if (result case Err(:final failure)) {
          log.info(
            'Wallet backup recovery material not registered at start-up',
            error: failure.runtimeType,
          );
        }
      }),
    );
    graph.triggers.start();
  }
}

final class _WalletBackupGraph {
  final WalletMetadataBackupImpl metadata;
  final WalletBackupJobRunner runner;
  final WalletBackupTriggers triggers;
  final RegisterWalletBackupRecoveryMaterialUsecase registerRecoveryMaterial;
  final WalletBackupFacade facade;

  const _WalletBackupGraph({
    required this.metadata,
    required this.runner,
    required this.triggers,
    required this.registerRecoveryMaterial,
    required this.facade,
  });

  factory _WalletBackupGraph.build(GetIt locator) {
    final definitions = WalletDefinitionsBackupImpl(
      locator<GetWalletDefinitionsUsecase>().execute,
      locator<RestoreWalletDefinitionUsecase>().execute,
      locator<WatchWalletCatalogChangesUsecase>().execute,
    );
    final labels = locator<LabelsFacade>();
    final database = locator<SqliteDatabase>();
    final payjoin = locator<PayjoinPolicyAccess>();
    final portableSettings = WalletPortableSettingsBackup(
      settings: locator<SettingsRepository>(),
      autoswap: locator<AutoSwapSettingsRepository>(),
      electrumServers: locator<ElectrumServerRepository>(),
      electrumSettings: locator<ElectrumSettingsRepository>(),
      mempoolServers: locator<MempoolServerRepository>(),
      mempoolSettings: locator<MempoolSettingsRepository>(),
      payjoin: payjoin,
      walletExists: locator<WalletRepository>().containsWallet,
    );
    final metadata = WalletMetadataBackupImpl(
      labels: labels,
      getFrozenOutpoints: locator<GetFrozenWalletOutpointsUsecase>().execute,
      restoreFrozenOutpoints:
          locator<RestoreFrozenWalletOutpointsUsecase>().execute,
      getPreferences: locator<GetWalletPreferencesUsecase>().execute,
      applyPreferences:
          locator<ApplyRecoveredWalletPreferencesUsecase>().execute,
      readPortableSettings: portableSettings.read,
      restorePortableSettings: portableSettings.restore,
      changeStreams: [
        labels.changes,
        locator<WatchWalletUtxoFreezeChangesUsecase>().execute(),
        locator<WatchWalletPreferenceChangesUsecase>().execute(),
        database.select(database.settings).watch().skip(1).map((_) {}),
        database.select(database.autoSwap).watch().skip(1).map((_) {}),
        database.select(database.electrumServers).watch().skip(1).map((_) {}),
        database.select(database.electrumSettings).watch().skip(1).map((_) {}),
        database.select(database.mempoolServers).watch().skip(1).map((_) {}),
        database.select(database.mempoolSettings).watch().skip(1).map((_) {}),
        payjoin.watch().skip(1).map((_) {}),
      ],
    );
    final keychainManifest = locator<KeychainManifestFacade>();
    final codec = WalletBackupSnapshotCodec(
      encodeManifest: keychainManifest.encodeManifestFilePayload,
      decodeManifest: keychainManifest.parseManifestFilePayload,
    );
    final encryption = RecoverBullWalletBackupEncryptionRepository(codec);
    final state = DriftWalletBackupStateRepository(database);
    Future<Uri> originProvider() async {
      switch (await state.get()) {
        case Ok(:final value):
          final origin = parseWalletBackupServerOrigin(
            value.customServerUrl ?? walletBackupDefaultServerUrl,
          );
          if (origin == null) throw const _WalletBackupOriginException();
          return origin;
        case Err():
          throw const _WalletBackupOriginException();
      }
    }

    final remote = MetadataBackupHttpRepository.defaults(
      origin: originProvider,
    );
    final nostrIdentity = locator<NostrIdentityFacade>();
    final authenticator = WalletBackupAuthenticator(nostrIdentity);
    final fetchRemote = FetchWalletBackupRemoteUsecase(remote, authenticator);
    final storeRemote = StoreWalletBackupRemoteUsecase(remote, authenticator);
    final deleteRemote = DeleteWalletBackupRemoteUsecase(remote, authenticator);
    final resolveKey = ResolveWalletBackupKeyUsecase(
      locator<GetSettingsUsecase>(),
      locator<GetDefaultSeedUsecase>(),
    );
    final wallets = locator<WalletRepository>();
    final refreshManifest = RefreshWalletRecoveryManifestUsecase(
      wallets.getSeedDerivedWalletRecoveryFacts,
      keychainManifest,
    );
    final recoveryInventory = GetWalletRecoveryInventoryUsecase(
      resolveKey.execute,
      refreshManifest.execute,
      keychainManifest.readManifest,
    );
    final buildSnapshot = BuildWalletBackupSnapshotUsecase(
      keychainManifest,
      definitions,
      metadata.localSnapshot,
    );
    final registerRecoveryMaterial =
        RegisterWalletBackupRecoveryMaterialUsecase(
          resolveKey,
          nostrIdentity,
          keychainManifest,
          refreshManifest,
        );
    final fetchImport = FetchWalletBackupSnapshotUsecase(
      resolveKey: resolveKey,
      encryption: encryption,
      state: state,
    );
    final publish = PublishWalletBackupUsecase(
      buildSnapshot: buildSnapshot,
      resolveKey: resolveKey,
      encryption: encryption,
      fetchRemote: fetchRemote,
      storeRemote: storeRemote,
      readRemoteSnapshot: fetchImport,
      state: state,
    );
    final publication = BackupWalletNowUsecase(
      state: state,
      publish: publish.execute,
      nowSecs: _nowSecs,
    );
    final runner = WalletBackupJobRunner(publish: publication.execute);
    final applySnapshot = ApplyBackupSnapshotUsecase(
      state,
      definitions,
      restoreManifest: RestoreWalletBackupManifestUsecase(
        wallets.matchesSeedDerivedRecoveryIdentity,
        keychainManifest,
      ),
      validateMetadata: metadata.validate,
      restoreMetadata: metadata.recover,
    );
    final decodeFile = DecodeWalletBackupFileUsecase(
      resolveKey.execute,
      encryption,
    );
    final recover = RecoverWalletBackupUsecase(
      fetchImport: fetchImport.execute,
      fetchRemote: fetchRemote.execute,
      apply: applySnapshot.execute,
    );
    final triggers = WalletBackupTriggers(
      // The manifest records its own revision inside the transaction that
      // changes it (decision 7); every other owner commits outside this
      // database or outside a repository this feature can reach.
      recordedChanges: keychainManifest.watchCommittedChanges(),
      unrecordedChanges: _mergeChanges([definitions.changes, metadata.changes]),
      syncResults: locator<WatchElectrumSyncResultsUsecase>().execute(),
      runner: runner,
      recordMutation: state.recordLocalMutation,
    );
    final facade = WalletBackupFacade(
      GetWalletBackupContentsUsecase(
        recoveryInventory.execute,
        locator<GetWalletDefinitionsUsecase>().execute,
        wallets.getLocallyKeyedWalletIds,
        metadata.localSnapshot,
      ),
      WatchWalletBackupStateUsecase(state),
      SetWalletBackupEnabledUsecase(
        state,
        recover.execute,
        registerRecoveryMaterial.execute,
        publication.execute,
      ),
      SetWalletBackupServerUsecase(
        state,
        parseOrigin: parseWalletBackupServerOrigin,
      ),
      DeleteWalletBackupUsecase(
        fetchRemote: fetchRemote,
        deleteRemote: deleteRemote,
        state: state,
      ),
      runner,
      state,
      recover,
      BuildWalletBackupExportUsecase(
        buildSnapshot: buildSnapshot.execute,
        resolveKey: resolveKey.execute,
        encryption: encryption,
      ),
      CompareWalletBackupFileUsecase(
        decodeFile.execute,
        state.get,
        fetchRemote.execute,
        fetchImport.execute,
        codec.differences,
      ),
      RecoverWalletBackupFileUsecase(
        decodeFile.execute,
        ({required snapshot, deadline}) => applySnapshot.execute(
          snapshot: snapshot,
          deadline: deadline,
          callerSettlesFence: true,
        ),
        applySnapshot.settle,
        state.get,
        fetchRemote.execute,
        StoreSelectedWalletBackupUsecase(
          resolveKey,
          encryption,
          storeRemote,
          state,
          _nowSecs,
        ).execute,
      ),
    );
    return _WalletBackupGraph(
      metadata: metadata,
      runner: runner,
      triggers: triggers,
      registerRecoveryMaterial: registerRecoveryMaterial,
      facade: facade,
    );
  }

  Future<void> dispose() async {
    await triggers.dispose();
    await runner.dispose();
    await metadata.dispose();
  }
}

int _nowSecs() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

Stream<void> _mergeChanges(List<Stream<void>> streams) =>
    StreamGroup.merge(streams);

final class _WalletBackupOriginException implements Exception {
  const _WalletBackupOriginException();
}
