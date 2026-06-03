import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/keychain_manifest/application/ports/keychain_manifest_entry_store.dart';
import 'package:bb_mobile/features/keychain_manifest/application/usecases/delete_keychain_manifest_wallet_entries_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/application/usecases/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/frameworks/drift_keychain_manifest_entry_store.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:get_it/get_it.dart';

class KeychainManifestLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<KeychainManifestEntryStore>(
      () =>
          DriftKeychainManifestEntryStore(database: locator<SqliteDatabase>()),
    );
    locator.registerFactory<RecordKeychainManifestEntryUsecase>(
      () => RecordKeychainManifestEntryUsecase(
        store: locator<KeychainManifestEntryStore>(),
      ),
    );
    locator.registerFactory<DeleteKeychainManifestWalletEntriesUsecase>(
      () => DeleteKeychainManifestWalletEntriesUsecase(
        store: locator<KeychainManifestEntryStore>(),
      ),
    );
    locator.registerFactory<KeychainManifestFacade>(
      () => KeychainManifestFacade(
        recordEntry: locator<RecordKeychainManifestEntryUsecase>(),
        deleteWalletEntries:
            locator<DeleteKeychainManifestWalletEntriesUsecase>(),
      ),
    );
  }
}
