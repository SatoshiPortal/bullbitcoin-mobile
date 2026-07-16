import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';

final class PublishAutomatedKeychainBackupUsecase {
  final KeychainManifestFacade keychainManifest;

  const PublishAutomatedKeychainBackupUsecase(this.keychainManifest);

  Future<void> execute() => keychainManifest.backupNow();
}
