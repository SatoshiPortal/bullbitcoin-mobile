import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart' show WalletRegistration;
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:meta/meta.dart';

class RecoverOnboardingWalletUsecase {
  final DefaultWalletProvisioning _defaultWallets;
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
    final restored = await _defaultWallets.execute(
      mnemonicWords: mnemonicWords,
      language: language,
      passphrase: passphrase,
    );
    if (restored case Err()) {
      return const Err(OnboardingWalletSetupFailure());
    }

    try {
      final wallets =
          (restored as Ok<List<WalletRegistration>, DefaultWalletFailure>)
              .value;
      await _completePhysicalBackupVerificationUsecase.execute(wallets);
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
