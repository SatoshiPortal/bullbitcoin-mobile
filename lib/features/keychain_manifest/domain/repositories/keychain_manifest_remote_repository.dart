import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';

abstract interface class KeychainManifestRemoteRepository {
  Future<KeychainManifestRemoteBackup> fetch(
    KeychainManifestBackupSigner signer,
  );

  Future<KeychainManifestRemoteCheckpoint> store({
    required KeychainManifestBackupSigner signer,
    required KeychainManifestRemoteBackup current,
    required AuthenticatedBackupCiphertext ciphertext,
  });

  Future<KeychainManifestRemoteCheckpoint?> delete({
    required KeychainManifestBackupSigner signer,
    required KeychainManifestRemoteBackup current,
  });
}
