import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:meta/meta.dart';

/// Detects changes committed in Payjoin's separate database while no backup
/// listener was running. Reading must succeed before recording the observation.
final class ReconcilePayjoinBackupUsecase {
  final WalletBackupStateRepository _state;
  final Future<WalletPayjoinSettings> Function() _readPolicy;

  const ReconcilePayjoinBackupUsecase(this._state, this._readPolicy);

  @useResult
  Future<Result<int, WalletBackupFailure>> execute() async {
    final WalletPayjoinSettings policy;
    try {
      policy = await _readPolicy();
    } on Exception {
      return const Err(
        WalletBackupStorageFailure('Could not read Payjoin policy'),
      );
    }
    return _state.recordObservedPayjoinPolicy(policy);
  }
}
