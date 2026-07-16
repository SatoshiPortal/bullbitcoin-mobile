import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_state.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';

abstract interface class KeychainManifestBackupStateRepository {
  Future<KeychainManifestBackupState> get();

  Stream<KeychainManifestBackupState> watch();

  Future<void> setEnabled(bool enabled);

  Future<void> recordAttempt(int attemptedAt);

  Future<void> recordSuccess({
    required int capturedDirtyRevision,
    required int succeededAt,
    required KeychainManifestRemoteCheckpoint checkpoint,
    required String contentHash,
  });

  Future<void> blockUnsupportedVersion(int version);

  Future<void> clearRemoteCheckpoint();
}
