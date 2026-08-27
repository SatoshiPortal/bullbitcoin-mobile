import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery_outcome.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

abstract interface class WalletBackupRecoveryOutcomeRepository {
  @useResult
  Future<Result<void, WalletBackupFailure>> save(
    WalletBackupRecoveryOutcome outcome,
  );

  @useResult
  Future<Result<WalletBackupRecoveryOutcome?, WalletBackupFailure>> read();
}
