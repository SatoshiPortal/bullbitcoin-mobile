import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_backup_snapshot_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_snapshot.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_encryption.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_encryption_repository.dart';

final class RecoverBullKeychainManifestEncryptionRepository
    implements KeychainManifestEncryptionRepository {
  final KeychainManifestBackupSnapshotCodec snapshotCodec;
  final RecoverBullAuthenticatedBackupCipher cipher;

  const RecoverBullKeychainManifestEncryptionRepository({
    this.snapshotCodec = const KeychainManifestBackupSnapshotCodec(),
    this.cipher = const RecoverBullAuthenticatedBackupCipher(),
  });

  @override
  AuthenticatedBackupCiphertext encryptSnapshot({
    required KeychainManifestBackupSnapshot snapshot,
    required KeychainManifestEncryptionKey key,
  }) {
    try {
      return cipher.encrypt(
        plaintext: snapshotCodec.encode(snapshot),
        key: key.cipherKey,
      );
    } on AuthenticatedBackupCipherException catch (error) {
      throw KeychainManifestEncryptionException(
        'failed to encrypt manifest content',
        cause: error,
      );
    }
  }

  @override
  KeychainManifestBackupSnapshot decryptSnapshot({
    required AuthenticatedBackupCiphertext ciphertext,
    required KeychainManifestEncryptionKey key,
  }) {
    try {
      return snapshotCodec.decode(
        cipher.decrypt(ciphertext: ciphertext, key: key.cipherKey),
      );
    } on KeychainManifestException {
      rethrow;
    } on AuthenticatedBackupCipherException catch (error) {
      throw KeychainManifestEncryptionException(
        'failed to decrypt manifest content',
        cause: error,
      );
    }
  }
}
