import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:meta/meta.dart';

class RecoverOnboardingWalletUsecase {
  final GetWalletsUsecase _getWallets;
  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;
  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;

  RecoverOnboardingWalletUsecase({
    required this._getWallets,
    required this._createDefaultWalletsUsecase,
    required this._completePhysicalBackupVerificationUsecase,
  });

  @useResult
  Future<Result<Map<String, String?>, OnboardingFailure>> execute({
    required List<String> mnemonicWords,
  }) async {
    final initialLabels = <String, String?>{};
    try {
      Set<String> existing;
      try {
        existing = (await _getWallets.execute(
          includeHidden: true,
        )).map((wallet) => wallet.id).toSet();
      } on NoWalletsFoundException {
        existing = {};
      }
      final wallets = await _createDefaultWalletsUsecase.execute(
        mnemonicWords: mnemonicWords,
      );
      for (final wallet in wallets) {
        if (!existing.contains(wallet.id)) {
          initialLabels[wallet.id] = wallet.label;
        }
      }
    } catch (e, st) {
      log.severe(
        message: 'Onboarding: wallet recovery failed',
        error: e,
        trace: st,
      );
      return const Err(OnboardingWalletSetupFailure());
    }

    try {
      await _completePhysicalBackupVerificationUsecase.execute();
    } catch (e, st) {
      log.severe(
        message: 'Onboarding: backup verification failed',
        error: e,
        trace: st,
      );
      return const Err(OnboardingBackupVerificationFailure());
    }

    return Ok(Map.unmodifiable(initialLabels));
  }
}
