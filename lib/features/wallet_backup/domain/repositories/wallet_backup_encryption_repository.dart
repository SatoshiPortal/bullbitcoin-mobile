import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_envelope.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupEncryptionRepository {
  @useResult
  Result<String, WalletBackupFailure> contentHash(
    WalletBackupEnvelope envelope,
  );

  @useResult
  Result<WalletBackupCiphertext, WalletBackupFailure> encrypt({
    required WalletBackupEnvelope envelope,
    required WalletBackupEncryptionKey key,
  });

  @useResult
  Result<WalletBackupEnvelope, WalletBackupFailure> decrypt({
    required WalletBackupCiphertext ciphertext,
    required WalletBackupEncryptionKey key,
    required String expectedParentFingerprint,
  });
}
