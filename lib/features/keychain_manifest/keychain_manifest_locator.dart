import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/data/drift_keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:get_it/get_it.dart';

class KeychainManifestLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<KeychainManifestEntryRepository>(
      () => DriftKeychainManifestEntryRepository(
        database: locator<SqliteDatabase>(),
      ),
    );
    locator.registerFactory<RecordKeychainManifestEntryUsecase>(
      () => RecordKeychainManifestEntryUsecase(
        repository: locator<KeychainManifestEntryRepository>(),
        bip85Registry: locator<Bip85RegistryFacade>(),
      ),
    );
    locator.registerFactory<KeychainManifestFacade>(
      () => KeychainManifestFacade(
        recordEntry: locator<RecordKeychainManifestEntryUsecase>(),
      ),
    );
  }
}
