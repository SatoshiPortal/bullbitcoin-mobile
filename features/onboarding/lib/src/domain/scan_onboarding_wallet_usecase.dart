import 'package:wallet_import/wallet_import.dart';
import 'package:onboarding/src/domain/onboarding_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:meta/meta.dart';

class ScanOnboardingWalletUsecase {
  const ScanOnboardingWalletUsecase(this._scan);
  final ImportFeature _scan;

  @useResult
  Future<Result<bool, OnboardingFailure>> execute({
    required List<String> words,
    required Language language,
    required String passphrase,
  }) async => switch (await _scan.hasBitcoinHistory(
    words: words,
    language: language,
    passphrase: passphrase,
  )) {
    Ok(:final value) => Ok(value),
    Err() => const Err(OnboardingWalletScanFailure()),
  };
}
