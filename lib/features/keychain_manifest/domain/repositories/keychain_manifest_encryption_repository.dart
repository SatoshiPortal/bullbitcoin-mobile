import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_snapshot.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_encryption.dart';

abstract interface class KeychainManifestEncryptionRepository {
  AuthenticatedBackupCiphertext encryptSnapshot({
    required KeychainManifestBackupSnapshot snapshot,
    required KeychainManifestEncryptionKey key,
  });

  KeychainManifestBackupSnapshot decryptSnapshot({
    required AuthenticatedBackupCiphertext ciphertext,
    required KeychainManifestEncryptionKey key,
  });
}
