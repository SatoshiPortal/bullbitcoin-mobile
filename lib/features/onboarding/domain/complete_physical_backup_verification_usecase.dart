import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:meta/meta.dart';

class CompletePhysicalBackupVerificationUsecase {
  final TestWalletBackupFacade _testWalletBackupFacade;

  CompletePhysicalBackupVerificationUsecase(this._testWalletBackupFacade);

  @useResult
  Future<Result<void, OnboardingFailure>> execute({
    required String masterFingerprint,
  }) async {
    switch (await _testWalletBackupFacade.completePhysicalBackupVerification(
      masterFingerprint: masterFingerprint,
    )) {
      case Ok():
        return const Ok(null);
      case Err(:final failure):
        return Err(OnboardingUnexpectedFailure(failure.logMessage));
    }
  }
}
