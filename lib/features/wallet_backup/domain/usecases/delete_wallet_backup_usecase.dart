import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class DeleteWalletBackupUsecase {
  final WalletBackupRemoteRepository _remote;
  final WalletBackupStateRepository _state;

  const DeleteWalletBackupUsecase({
    required this._remote,
    required this._state,
  });

  @useResult
  Future<Result<void, WalletBackupFailure>> execute({
    required bool confirmed,
  }) async {
    if (!confirmed) {
      return const Err(WalletBackupConfirmationRequiredFailure());
    }

    final fetchResult = await _remote.fetch();
    final WalletBackupRemoteHead current;
    switch (fetchResult) {
      case Ok(:final value):
        current = value;
      case Err(:final failure):
        return Err(failure);
    }
    final deleteResult = await _remote.delete(current: current);
    if (deleteResult case Err(:final failure)) return Err(failure);

    return _state.clearRemoteCheckpoint();
  }
}
