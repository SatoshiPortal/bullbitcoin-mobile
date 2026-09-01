import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

/// The encode-then-encrypt and decrypt-then-decode boundary.
///
/// Callers hand over and receive typed snapshots; the canonical wire form only
/// exists inside this repository.
abstract interface class WalletBackupEncryptionRepository {
  @useResult
  Result<Uint8List, WalletBackupFailure> encodeCanonical(
    WalletBackupSnapshot envelope,
  );

  @useResult
  Result<WalletBackupSnapshot, WalletBackupFailure> decodeCanonical({
    required Uint8List bytes,
    required String expectedParentFingerprint,
  });

  @useResult
  Result<WalletBackupCiphertext, WalletBackupFailure> encrypt({
    required WalletBackupSnapshot envelope,
    required WalletBackupEncryptionKey key,
  });

  @useResult
  Result<WalletBackupSnapshot, WalletBackupFailure> decrypt({
    required WalletBackupCiphertext ciphertext,
    required WalletBackupEncryptionKey key,
    required String expectedParentFingerprint,
  });
}
