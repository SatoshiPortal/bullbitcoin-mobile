import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

/// These run the real package against an in-memory keystore installed at the plugin's own seam, so duplicate detection uses the production fingerprint derivation.
void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late CheckDuplicateMnemonicUsecase usecase;

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    usecase = CheckDuplicateMnemonicUsecase(secrets: secrets);
  });

  group('CheckDuplicateMnemonicUsecase', () {
    test('returns Ok when the mnemonic is not stored', () async {
      expect(
        await usecase.execute(mnemonicWords: words),
        isA<Ok<void, ImportMnemonicFailure>>(),
      );
    });

    test('returns Err(duplicate) once the same mnemonic is stored', () async {
      expect(
        await secrets.import(words: words),
        isA<Ok<Secret, SecretFailure>>(),
      );

      final result = await usecase.execute(mnemonicWords: words);

      expect((result as Err).failure, isA<ImportMnemonicDuplicateFailure>());
    });

    test('a passphrase makes a different secret, not a duplicate', () async {
      expect(
        await secrets.import(words: words),
        isA<Ok<Secret, SecretFailure>>(),
      );

      final result = await usecase.execute(
        mnemonicWords: words,
        passphrase: 'TREZOR',
      );

      expect(result, isA<Ok<void, ImportMnemonicFailure>>());
    });

    test('a keystore error is unexpected, and carries no stored text', () async {
      const sentinel = 'SYNTHETIC_KEYSTORE_SENTINEL';
      expect(
        await secrets.import(words: words),
        isA<Ok<Secret, SecretFailure>>(),
      );
      // contains now reads and compares the stored seed, so every retry must fail.
      storage.scripted.addAll(List.filled(5, Exception(sentinel)));

      final result = await usecase.execute(mnemonicWords: words);

      final failure = (result as Err).failure;
      expect(failure, isA<ImportMnemonicUnexpectedFailure>());
      // The package reports a foreign exception by type; the message it wrote never reaches this layer, so neither does anything the keystore held.
      expect(failure.logMessage, isNot(contains(sentinel)));
    });
  });
}
