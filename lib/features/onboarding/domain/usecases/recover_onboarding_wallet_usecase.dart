import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:onboarding/onboarding.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
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
  Future<Result<void, OnboardingFailure>> execute({
    required List<String> mnemonicWords,
    required Language language,
    String passphrase = '',
  }) async {
    if (await _defaultWallets.restore(
          words: mnemonicWords,
          language: language,
          passphrase: passphrase,
        )
        case Err()) {
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

    return const Ok(null);
  }
}
