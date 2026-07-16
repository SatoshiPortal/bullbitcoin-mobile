import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';

final class KeychainManifestEncryptionKey {
  final String hex;
  final AuthenticatedBackupCipherKey cipherKey;

  KeychainManifestEncryptionKey(String hex)
    : hex = hex.trim().toLowerCase(),
      cipherKey = _validatedCipherKey(hex);

  static AuthenticatedBackupCipherKey _validatedCipherKey(String hex) {
    try {
      return AuthenticatedBackupCipherKey(hex);
    } on AuthenticatedBackupCipherException catch (error) {
      throw KeychainManifestEncryptionException(
        'manifest encryption key must be a 32-byte hex value',
        cause: error,
      );
    }
  }
}
