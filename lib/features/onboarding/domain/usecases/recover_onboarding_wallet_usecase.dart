import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:meta/meta.dart';

class RecoverOnboardingWalletUsecase {
  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;
  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;

  RecoverOnboardingWalletUsecase({
    required this._createDefaultWalletsUsecase,
    required this._completePhysicalBackupVerificationUsecase,
  });

  @useResult
  Future<Result<List<WalletPreferences>, OnboardingFailure>> execute({
    required List<String> mnemonicWords,
  }) async {
    final DefaultWalletsResult restored;
    try {
      restored = await _createDefaultWalletsUsecase.execute(
        mnemonicWords: mnemonicWords,
      );
    } catch (e, st) {
      log.severe(
        message: 'Onboarding: wallet recovery failed',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(OnboardingWalletSetupFailure());
    }

    try {
      await _completePhysicalBackupVerificationUsecase.execute();
    } catch (e, st) {
      log.severe(
        message: 'Onboarding: backup verification failed',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(OnboardingBackupVerificationFailure());
    }

    return Ok(restored.createdWalletPreferences);
  }
}
