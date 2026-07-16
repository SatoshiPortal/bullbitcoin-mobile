import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_wallet.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/data/bullnym_keychain_manifest_remote_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/data/drift_keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_backup_wallet_adapter.dart';
import 'package:bb_mobile/features/keychain_manifest/data/drift_keychain_manifest_backup_state_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/data/recoverbull_keychain_manifest_encryption_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_backup_state_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_encryption_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_remote_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/delete_keychain_manifest_backup_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/get_keychain_manifest_backup_state_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/fetch_keychain_manifest_remote_import_plan_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/flush_keychain_manifest_backup_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/set_keychain_manifest_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/sync_keychain_manifest_backup_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/watchers/keychain_manifest_backup_watcher.dart';
import 'package:get_it/get_it.dart';

class KeychainManifestLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<KeychainManifestEntryRepository>(
      () => DriftKeychainManifestEntryRepository(
        database: locator<SqliteDatabase>(),
      ),
    );
    locator.registerLazySingleton<KeychainManifestBackupStateRepository>(
      () =>
          DriftKeychainManifestBackupStateRepository(locator<SqliteDatabase>()),
    );
    locator.registerLazySingleton<KeychainManifestBackupWalletPort>(
      () => KeychainManifestBackupWalletAdapter(
        getSettings: locator<GetSettingsUsecase>(),
        wallets: locator<WalletRepository>(),
        seeds: locator<SeedRepository>(),
      ),
    );
    locator.registerLazySingleton<KeychainManifestEncryptionRepository>(
      () => const RecoverBullKeychainManifestEncryptionRepository(),
    );
    locator.registerLazySingleton<KeychainManifestRemoteRepository>(
      () => BullnymKeychainManifestRemoteRepository(locator<BullnymFacade>()),
    );
    locator.registerFactory<RecordKeychainManifestEntryUsecase>(
      () => RecordKeychainManifestEntryUsecase(
        repository: locator<KeychainManifestEntryRepository>(),
        bip85Registry: locator<Bip85RegistryFacade>(),
        clock: locator<Clock>(),
      ),
    );
    locator.registerFactory<BuildKeychainManifestFileUsecase>(
      () => BuildKeychainManifestFileUsecase(
        repository: locator<KeychainManifestEntryRepository>(),
        registry: locator<Bip85RegistryFacade>(),
        clock: locator<Clock>(),
      ),
    );
    locator.registerFactory<ParseKeychainManifestFileUsecase>(
      () => ParseKeychainManifestFileUsecase(
        codec: const KeychainManifestFileCodec(),
        bip85Registry: locator<Bip85RegistryFacade>(),
      ),
    );
    locator.registerFactory<SyncKeychainManifestBackupUsecase>(
      () => SyncKeychainManifestBackupUsecase(
        buildManifestFile: locator<BuildKeychainManifestFileUsecase>(),
        encryption: locator<KeychainManifestEncryptionRepository>(),
        remote: locator<KeychainManifestRemoteRepository>(),
        identity: locator<NostrIdentityFacade>(),
        parseManifest: locator<ParseKeychainManifestFileUsecase>(),
      ),
    );
    locator.registerLazySingleton<FlushKeychainManifestBackupUsecase>(
      () => FlushKeychainManifestBackupUsecase(
        state: locator<KeychainManifestBackupStateRepository>(),
        wallet: locator<KeychainManifestBackupWalletPort>(),
        sync: locator<SyncKeychainManifestBackupUsecase>(),
        clock: locator<Clock>(),
      ),
    );
    locator.registerLazySingleton<KeychainManifestBackupWatcher>(
      () => KeychainManifestBackupWatcher(
        watchSyncResults: locator<WatchElectrumSyncResultsUsecase>(),
        flush: locator<FlushKeychainManifestBackupUsecase>(),
      ),
      dispose: (watcher) => watcher.dispose(),
    );
    locator.registerFactory<GetKeychainManifestBackupStateUsecase>(
      () => GetKeychainManifestBackupStateUsecase(
        locator<KeychainManifestBackupStateRepository>(),
      ),
    );
    locator.registerFactory<SetKeychainManifestBackupEnabledUsecase>(
      () => SetKeychainManifestBackupEnabledUsecase(
        locator<KeychainManifestBackupStateRepository>(),
      ),
    );
    locator.registerFactory<DeleteKeychainManifestBackupUsecase>(
      () => DeleteKeychainManifestBackupUsecase(
        remote: locator<KeychainManifestRemoteRepository>(),
        state: locator<KeychainManifestBackupStateRepository>(),
        identity: locator<NostrIdentityFacade>(),
        wallet: locator<KeychainManifestBackupWalletPort>(),
      ),
    );
    locator.registerFactory<FetchKeychainManifestRemoteImportPlanUsecase>(
      () => FetchKeychainManifestRemoteImportPlanUsecase(
        remote: locator<KeychainManifestRemoteRepository>(),
        encryption: locator<KeychainManifestEncryptionRepository>(),
        parseManifest: locator<ParseKeychainManifestFileUsecase>(),
        identity: locator<NostrIdentityFacade>(),
        wallet: locator<KeychainManifestBackupWalletPort>(),
      ),
    );
    locator.registerFactory<KeychainManifestFacade>(
      () => KeychainManifestFacade(
        recordEntry: locator<RecordKeychainManifestEntryUsecase>(),
        buildManifestFile: locator<BuildKeychainManifestFileUsecase>(),
        parseManifestFile: locator<ParseKeychainManifestFileUsecase>(),
        getBackupState: locator<GetKeychainManifestBackupStateUsecase>(),
        setBackupEnabled: locator<SetKeychainManifestBackupEnabledUsecase>(),
        deleteBackup: locator<DeleteKeychainManifestBackupUsecase>(),
        fetchRemoteImportPlan:
            locator<FetchKeychainManifestRemoteImportPlanUsecase>(),
        flushBackup: locator<FlushKeychainManifestBackupUsecase>(),
      ),
    );
  }

  static void start(GetIt locator) {
    locator<KeychainManifestBackupWatcher>().start();
  }
}
