import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';

import '../onboarding_failure.dart';
import 'complete_physical_backup_verification_usecase.dart';

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
    return switch (restored) {
      Err() => const Err(OnboardingWalletSetupFailure()),
      Ok(value: final wallets) =>
        await _completePhysicalBackupVerificationUsecase.execute(wallets),
    };
  }
}
