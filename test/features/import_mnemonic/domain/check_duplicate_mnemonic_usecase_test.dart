import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

/// `Secrets` is `final`, so there is no double of it — by design. These run the real package against an in-memory keystore installed at the plugin's own seam, which means the identity this usecase compares is derived by the same code that will derive it in production.
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
      await secrets.import(words: words);

      final result = await usecase.execute(mnemonicWords: words);

      expect((result as Err).failure, isA<ImportMnemonicDuplicateFailure>());
    });

    test('a passphrase makes a different secret, not a duplicate', () async {
      await secrets.import(words: words);

      final result = await usecase.execute(
        mnemonicWords: words,
        passphrase: 'TREZOR',
      );

      expect(result, isA<Ok<void, ImportMnemonicFailure>>());
    });

    test('a keystore error is unexpected, and carries no stored text', () async {
      const sentinel = 'SYNTHETIC_KEYSTORE_SENTINEL';
      await secrets.import(words: words);
      storage.scripted.add(Exception(sentinel));

      final result = await usecase.execute(mnemonicWords: words);

      final failure = (result as Err).failure;
      expect(failure, isA<ImportMnemonicUnexpectedFailure>());
      // The package reports a foreign exception by type; the message it wrote never reaches this layer, so neither does anything the keystore held.
      expect(failure.logMessage, isNot(contains(sentinel)));
    });
  });
}
