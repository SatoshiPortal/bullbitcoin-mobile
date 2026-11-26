import 'package:wallet_import/wallet_import.dart';
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/src/domain/usecases/scan_onboarding_wallet_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Scan extends Mock implements ImportFeature {}

void main() {
  setUpAll(() => registerFallbackValue(Language.english));
  test('a failed scan is an error, never an empty wallet', () async {
    final scan = _Scan();
    when(
      () => scan.hasBitcoinHistory(
        words: any(named: 'words'),
        language: any(named: 'language'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) async => const Err(ImportMnemonicScanTimeoutFailure()));
    final result = await ScanOnboardingWalletUsecase(scan).execute(
      words: const ['word'],
      language: Language.english,
      passphrase: ' pass ',
    );
    expect(result, isA<Err<bool, OnboardingFailure>>());
  });
}
