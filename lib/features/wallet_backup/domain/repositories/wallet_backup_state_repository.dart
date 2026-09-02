import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupStateRepository {
  @useResult
  Future<Result<WalletBackupState, WalletBackupFailure>> get();

  @useResult
  Stream<Result<WalletBackupState, WalletBackupFailure>> watch();

  @useResult
  Future<Result<void, WalletBackupFailure>> setEnabled(bool enabled);

  /// Records a backup-relevant local mutation whose owner could not record it
  /// inside its own transaction, and answers the revision it produced.
  @useResult
  Future<Result<int, WalletBackupFailure>> recordLocalMutation();

  /// Acknowledges [publishedRevision] as stored remotely. Anything committed
  /// during the store keeps the backup dirty, because the local revision has
  /// moved past what the server holds.
  @useResult
  Future<Result<void, WalletBackupFailure>> recordPublication({
    required int publishedRevision,
    required int succeededAt,
    required WalletBackupRemoteCheckpoint checkpoint,
  });

  /// Records the head last fetched and authenticated, without claiming a
  /// successful publication. Null clears the checkpoint.
  @useResult
  Future<Result<void, WalletBackupFailure>> saveRemoteCheckpoint(
    WalletBackupRemoteCheckpoint? checkpoint,
  );

  @useResult
  Future<Result<void, WalletBackupFailure>> blockUnsupportedVersion(
    int version,
  );

  @useResult
  Future<Result<void, WalletBackupFailure>> setRecoveryState(
    WalletBackupRecoveryState state,
  );

  @useResult
  Future<Result<void, WalletBackupFailure>> clearRemoteCheckpoint();

  @useResult
  Future<Result<void, WalletBackupFailure>> saveRecoveryOutcome(
    WalletBackupRecoveryStatus status,
  );

  @useResult
  Future<Result<void, WalletBackupFailure>> setServerUrl(String? serverUrl);
}
