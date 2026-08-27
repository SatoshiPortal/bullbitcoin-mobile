import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupRemoteRepository {
  @useResult
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> fetch();

  @useResult
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> store({
    required WalletBackupRemoteHead current,
    required WalletBackupCiphertext ciphertext,
  });

  @useResult
  Future<Result<WalletBackupRemoteCheckpoint?, WalletBackupFailure>> delete({
    required WalletBackupRemoteHead current,
  });
}
