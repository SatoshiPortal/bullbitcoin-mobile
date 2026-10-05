import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Records that the physical backup was verified successfully.
class CompleteBackupVerificationUsecase {
  final CompletePhysicalBackupVerificationUsecase _completeVerificationUsecase;

  const CompleteBackupVerificationUsecase(this._completeVerificationUsecase);

  @useResult
  Future<Result<void, TestWalletBackupFailure>> execute() async {
    try {
      await _completeVerificationUsecase.execute();
      return const Ok(null);
    } on Object catch (e, st) {
      log.severe(
        message: 'Failed to record the physical backup verification',
        error: e,
        trace: st,
      );
      return Err(TestWalletBackupCompletionFailure(e.toString()));
    }
  }
}
