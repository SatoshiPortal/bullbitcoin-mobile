import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart'
    show TestWalletBackupFailure;

class TestWalletBackupFacade {
  final CompletePhysicalBackupVerificationUsecase _completeVerification;

  TestWalletBackupFacade(this._completeVerification);

  @useResult
  Future<Result<void, TestWalletBackupFailure>>
  completePhysicalBackupVerification({required String masterFingerprint}) =>
      _completeVerification.execute(masterFingerprint: masterFingerprint);
}
