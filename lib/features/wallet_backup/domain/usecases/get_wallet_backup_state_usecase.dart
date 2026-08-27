import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class GetWalletBackupStateUsecase {
  final WalletBackupStateRepository _repository;

  const GetWalletBackupStateUsecase(this._repository);

  @useResult
  Future<Result<WalletBackupState, WalletBackupFailure>> execute() {
    return _repository.get();
  }
}
