import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupRemoteRepository {
  @useResult
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> fetch({
    required WalletBackupAuthentication authentication,
  });

  /// Conditionally stores [ciphertext] against [current], returning the head
  /// the server acknowledged. [current] is null when nothing was ever stored.
  @useResult
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> store({
    required WalletBackupAuthentication authentication,
    required WalletBackupRemoteCheckpoint? current,
    required WalletBackupCiphertext ciphertext,
    required String ciphertextSha256,
  });

  /// Conditionally deletes the object at [current], returning the tombstone
  /// head the server acknowledged.
  @useResult
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> delete({
    required WalletBackupAuthentication authentication,
    required WalletBackupRemoteCheckpoint current,
  });
}
