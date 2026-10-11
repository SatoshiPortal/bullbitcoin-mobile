import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:meta/meta.dart';

class RecoverOnboardingWalletUsecase {
  final DefaultWalletsFacade _defaultWallets;
  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;

  RecoverOnboardingWalletUsecase({
    required this._defaultWallets,
    required this._completePhysicalBackupVerificationUsecase,
  });

  @useResult
  Future<Result<Map<String, String?>, OnboardingFailure>> execute({
    required List<String> mnemonicWords,
    String passphrase = '',
  }) async {
    final initialLabels = <String, String?>{};
    try {
      final Set<String> existing;
      switch (await _defaultWallets.existingWallets()) {
        case Ok(:final value):
          existing = value.map((wallet) => wallet.id).toSet();
        case Err():
          return const Err(OnboardingWalletSetupFailure());
      }
      final restored = await _defaultWallets.restore(
        words: mnemonicWords,
        passphrase: passphrase,
      );
      final wallets = switch (restored) {
        Ok(:final value) => value,
        Err() => null,
      };
      if (wallets == null) return const Err(OnboardingWalletSetupFailure());
      for (final wallet in wallets) {
        if (!existing.contains(wallet.id)) {
          initialLabels[wallet.id] = wallet.label;
        }
      }
    } on Exception catch (e, st) {
      log.severe(
        message: 'Onboarding: wallet recovery failed',
        error: e,
        trace: st,
      );
      return const Err(OnboardingWalletSetupFailure());
    }

    try {
      await _completePhysicalBackupVerificationUsecase.execute();
    } on Exception catch (e, st) {
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
