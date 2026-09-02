import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

/// Points Bull backup at another origin. The job runner serializes it against
/// publication, so no store can land on the origin that is being replaced.
final class SetWalletBackupServerUsecase {
  final WalletBackupStateRepository _state;
  final Uri? Function(String value) parseOrigin;

  const SetWalletBackupServerUsecase(this._state, {required this.parseOrigin});

  @useResult
  Future<Result<void, WalletBackupFailure>> execute(String value) async {
    final trimmed = value.trim();
    final origin = trimmed.isEmpty ? null : parseOrigin(trimmed);
    if (trimmed.isNotEmpty && origin == null) {
      return const Err(WalletBackupInvalidServerOriginFailure());
    }
    return _state.setServerUrl(origin?.toString());
  }
}
