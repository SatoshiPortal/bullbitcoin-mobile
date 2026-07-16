import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encryption_key.dart';

final class WalletMetadataCipherException implements Exception {
  const WalletMetadataCipherException();
}

final class WalletMetadataAuthenticatedCipher {
  final RecoverBullAuthenticatedBackupCipher _cipher;

  const WalletMetadataAuthenticatedCipher({
    this._cipher = const RecoverBullAuthenticatedBackupCipher(),
  });

  String encrypt({
    required String plaintext,
    required WalletMetadataEncryptionKey key,
  }) {
    try {
      return _cipher
          .encrypt(
            plaintext: plaintext,
            key: AuthenticatedBackupCipherKey(key.hex),
          )
          .value;
    } on AuthenticatedBackupCipherException {
      throw const WalletMetadataCipherException();
    }
  }

  String decrypt({
    required String ciphertext,
    required WalletMetadataEncryptionKey key,
  }) {
    try {
      return _cipher.decrypt(
        ciphertext: AuthenticatedBackupCiphertext(ciphertext),
        key: AuthenticatedBackupCipherKey(key.hex),
      );
    } on AuthenticatedBackupCipherException {
      throw const WalletMetadataCipherException();
    }
  }
}
