import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupStateRepository {
  @useResult
  Future<Result<WalletBackupState, WalletBackupFailure>> get();

  @useResult
  Stream<Result<WalletBackupState, WalletBackupFailure>> watch();

  @useResult
  Future<Result<void, WalletBackupFailure>> setEnabled(bool enabled);

  @useResult
  Future<Result<void, WalletBackupFailure>> markDirty();

  @useResult
  Future<Result<void, WalletBackupFailure>> recordAttempt(int attemptedAt);

  @useResult
  Future<Result<void, WalletBackupFailure>> recordSuccess({
    required int capturedDirtyRevision,
    required int succeededAt,
    required WalletBackupSyncResult syncResult,
  });

  @useResult
  Future<Result<void, WalletBackupFailure>> blockUnsupportedVersion(
    int version,
  );

  @useResult
  Future<Result<void, WalletBackupFailure>> setRecoveryBlocked(bool blocked);

  @useResult
  Future<Result<void, WalletBackupFailure>> clearRemoteCheckpoint();
}
