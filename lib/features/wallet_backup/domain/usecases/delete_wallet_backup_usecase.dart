import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/wallet_backup_remote_usecases.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class DeleteWalletBackupUsecase {
  final FetchWalletBackupRemoteUsecase _fetchRemote;
  final DeleteWalletBackupRemoteUsecase _deleteRemote;
  final WalletBackupStateRepository _state;

  const DeleteWalletBackupUsecase({
    required this._fetchRemote,
    required this._deleteRemote,
    required this._state,
  });

  @useResult
  Future<Result<void, WalletBackupFailure>> execute({
    required bool confirmed,
  }) async {
    if (!confirmed) {
      return const Err(WalletBackupConfirmationRequiredFailure());
    }

    final WalletBackupRemoteCheckpoint? checkpoint;
    switch (await _state.get()) {
      case Ok(:final value):
        // Decision 9: automatic backup has to be off first. It is also what
        // stops a publication queued behind this job from recreating the
        // object this one is about to remove.
        if (value.enabled) {
          return const Err(WalletBackupDeleteRequiresDisabledFailure());
        }
        checkpoint = value.remoteCheckpoint;
      case Err(:final failure):
        return Err(failure);
    }

    // A trusted checkpoint deletes without a fetch; without one, or when the
    // checkpoint turns out to be stale, the current head decides (spec 19.6).
    if (checkpoint != null) {
      switch (await _deleteRemote.execute(current: checkpoint)) {
        case Ok():
          return _state.clearRemoteCheckpoint();
        case Err(failure: WalletBackupHeadConflictFailure()):
          break;
        case Err(:final failure):
          return Err(failure);
      }
    }

    final WalletBackupRemoteCheckpoint? head;
    switch (await _fetchRemote.execute()) {
      case Ok(:final value):
        head = value.checkpoint;
      case Err(:final failure):
        return Err(failure);
    }
    if (head == null) return _state.clearRemoteCheckpoint();
    if (await _deleteRemote.execute(current: head) case Err(:final failure)) {
      return Err(failure);
    }
    return _state.clearRemoteCheckpoint();
  }
}
