import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_public_records_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/data/nostr_key_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/capture_keychain_manifest_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/nostr_key_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_backup_identities_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:get_it/get_it.dart';

abstract final class KeychainManifestLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<KeychainManifestRepository>(
      () => KeychainManifestRepositoryImpl(
        database: locator(),
        wallets: locator(),
        bip85: locator(),
        nostrKeys: locator(),
      ),
    );
    locator.registerFactory(() => CaptureKeychainManifestUsecase(locator()));
    locator.registerFactory(() => RestorePublicRecordsUsecase(locator()));
    locator.registerLazySingleton<NostrKeyRepository>(
      () => NostrKeyRepositoryImpl(locator()),
    );
    locator.registerFactory(() => GetNostrKeysUsecase(locator()));
    locator.registerFactory(() => WatchNostrKeysUsecase(locator()));
    locator.registerFactory(
      () => CreateNostrKeyUsecase(locator(), locator(), locator()),
    );
    locator.registerFactory(() => RevealNostrKeyUsecase(locator(), locator()));
    locator.registerFactory(() => GetBackupIdentitiesUsecase(locator()));
    locator.registerFactory(() => RevealBackupIdentityUsecase(locator()));
    locator.registerFactory(
      () => KeychainManifestFacade(locator(), locator(), locator()),
    );
  }
}
