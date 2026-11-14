import 'package:bb_mobile/features/import_mnemonic/public/import_mnemonic_scan_facade.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class ScanOnboardingWalletUsecase {
  const ScanOnboardingWalletUsecase(this._scan);
  final ImportMnemonicScanFacade _scan;

  @useResult
  Future<Result<bool, OnboardingFailure>> execute({
    required List<String> words,
    required String passphrase,
  }) async => switch (await _scan.hasBitcoinHistory(
    words: words,
    passphrase: passphrase,
  )) {
    Ok(:final value) => Ok(value),
    Err() => const Err(OnboardingWalletScanFailure()),
  };
}
