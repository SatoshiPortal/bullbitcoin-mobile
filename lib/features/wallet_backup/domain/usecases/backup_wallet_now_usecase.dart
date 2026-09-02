import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

typedef PublishWalletBackupSnapshot =
    Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> Function(
      WalletBackupRemoteCheckpoint? checkpoint,
    );

/// One publication pass, as the job runner runs it (spec 19.3).
///
/// It exits cheaply when there is nothing to send, captures the local revision
/// it is about to publish, and acknowledges only that revision. A mutation
/// committed while the store was in flight therefore leaves the backup dirty
/// and the runner schedules one more pass.
final class BackupWalletNowUsecase {
  final WalletBackupStateRepository _state;
  final PublishWalletBackupSnapshot _publish;
  final int Function() _nowSecs;

  const BackupWalletNowUsecase({
    required this._state,
    required this._publish,
    required this._nowSecs,
  });

  @useResult
  Future<Result<void, WalletBackupFailure>> execute() async {
    final WalletBackupState state;
    switch (await _state.get()) {
      case Ok(:final value):
        state = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (!state.enabled) {
      return const Err(WalletBackupDisabledFailure());
    }
    if (state.recoveryBlocked) {
      return const Err(WalletBackupRecoveryBlockedFailure());
    }
    if (state.unsupportedVersion case final version?) {
      return Err(WalletBackupUnsupportedEnvelopeVersionFailure(version));
    }
    if (!state.dirty) {
      return const Ok(null);
    }

    final publishedRevision = state.localRevision;
    final WalletBackupRemoteCheckpoint checkpoint;
    switch (await _publish(state.remoteCheckpoint)) {
      case Ok(:final value):
        checkpoint = value;
      case Err(:final failure):
        if (failure is WalletBackupUnsupportedEnvelopeVersionFailure) {
          final blockResult = await _state.blockUnsupportedVersion(
            failure.version,
          );
          if (blockResult case Err(:final failure)) return Err(failure);
        }
        return Err(failure);
    }

    return _state.recordPublication(
      publishedRevision: publishedRevision,
      succeededAt: _nowSecs(),
      checkpoint: checkpoint,
    );
  }
}
