import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_backup_state_repository.dart';

final class SetKeychainManifestBackupEnabledUsecase {
  final KeychainManifestBackupStateRepository repository;

  const SetKeychainManifestBackupEnabledUsecase(this.repository);

  Future<void> execute(bool enabled) => repository.setEnabled(enabled);
}
