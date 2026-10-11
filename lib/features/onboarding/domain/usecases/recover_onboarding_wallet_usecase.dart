import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
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
      final Set<String> existing;
      switch (await _getWallets.execute(includeHidden: true)) {
        case Ok(:final value):
          existing = value.map((wallet) => wallet.id).toSet();
        case Err(failure: NoWalletsFoundFailure()):
          existing = {};
        case Err():
          return const Err(OnboardingWalletSetupFailure());
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
