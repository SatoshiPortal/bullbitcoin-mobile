import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';

final class DeleteAutomatedKeychainBackupUsecase {
  final KeychainManifestFacade keychainManifest;

  const DeleteAutomatedKeychainBackupUsecase(this.keychainManifest);

  Future<void> execute() =>
      keychainManifest.deleteRemoteBackup(confirmed: true);
}
