import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

class SetWalletBackupRecoveryBlockedUsecase {
  final WalletBackupStateRepository _state;

  const SetWalletBackupRecoveryBlockedUsecase(this._state);

  @useResult
  Future<Result<void, WalletBackupFailure>> execute(bool blocked) =>
      _state.setRecoveryBlocked(blocked);
}
