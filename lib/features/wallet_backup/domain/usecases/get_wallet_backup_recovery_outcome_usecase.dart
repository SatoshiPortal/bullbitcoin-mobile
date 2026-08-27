import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery_outcome.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_recovery_outcome_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

final class GetWalletBackupRecoveryOutcomeUsecase {
  final WalletBackupRecoveryOutcomeRepository _repository;

  const GetWalletBackupRecoveryOutcomeUsecase(this._repository);

  @useResult
  Future<Result<WalletBackupRecoveryOutcome?, WalletBackupFailure>> execute() =>
      _repository.read();
}
