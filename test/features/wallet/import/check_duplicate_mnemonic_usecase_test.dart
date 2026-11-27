import 'package:wallet_import/wallet_import.dart';

import 'dart:io';

import 'package:primitives/primitives.dart' show BitcoinUnit, Err, Ok;
import 'package:preferences/preferences.dart';

import '../../../support/inventory_fixture.dart';

import 'package:mocktail/mocktail.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:unorm_dart/unorm_dart.dart' show nfc;
import 'package:wallet_import/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

/// These run the real package against an in-memory keystore installed at the plugin's own seam, so duplicate detection uses the production fingerprint derivation.
class _Settings extends Mock implements Preferences {}

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
  late InventoryFixture fixture;
  late _Settings settings;

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    final directory = await Directory.systemTemp.createTemp(
      'import-duplicate-',
    );
    addTearDown(() => directory.delete(recursive: true));
    fixture = await InventoryFixture.open(directory);
    addTearDown(fixture.close);
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    settings = _Settings();
    when(() => settings.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    usecase = CheckDuplicateMnemonicUsecase(
      secrets: secrets,
      inventory: fixture.inventory,
      settings: settings,
    );
  });

  for (final language in bip39.Language.values) {
    test(
      'recognizes ${language.name} duplicates across Unicode forms',
      () async {
        final words = bip39.Mnemonic(List.filled(16, 0), language).words;
        expect(
          await usecase.execute(mnemonicWords: words, language: language),
          isA<Ok<void, ImportMnemonicFailure>>(),
        );
        final imported = await secrets.import(words: words, language: language);
        final secret = switch (imported) {
          Ok(:final value) => value,
          Err(:final failure) => fail('import failed: ${failure.runtimeType}'),
        };
        await fixture.registerMnemonic(secret);
        final duplicate = await usecase.execute(
          mnemonicWords: words.map(nfc).toList(),
          language: language,
        );
        expect(
          (duplicate as Err).failure,
          isA<ImportMnemonicDuplicateFailure>(),
        );
        expect(
          await usecase.execute(
            mnemonicWords: words,
            language: language,
            passphrase: 'TREZOR',
          ),
          isA<Ok<void, ImportMnemonicFailure>>(),
        );
      },
    );
  }

  group('CheckDuplicateMnemonicUsecase', () {
    test('returns Ok when the mnemonic is not stored', () async {
      expect(
        await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        ),
        isA<Ok<void, ImportMnemonicFailure>>(),
      );
    });

    test('allows an orphan secret to be retried', () async {
      expect(
        await secrets.import(words: words, language: bip39.Language.english),
        isA<Ok<Secret, SecretFailure>>(),
      );

      final result = await usecase.execute(
        mnemonicWords: words,
        language: bip39.Language.english,
      );

      expect(result, isA<Ok<void, ImportMnemonicFailure>>());
    });

    test('rejects a referenced secret only on the target network', () async {
      final imported = await secrets.import(
        words: words,
        language: bip39.Language.english,
      );
      final secret = (imported as Ok<Secret, SecretFailure>).value;
      await fixture.registerMnemonic(secret);
      expect(
        await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        ),
        isA<Err<void, ImportMnemonicFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ImportMnemonicDuplicateFailure>(),
        ),
      );
      when(settings.fetch).thenAnswer(
        (_) async => const Ok(
          SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      expect(
        await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        ),
        isA<Ok<void, ImportMnemonicFailure>>(),
      );
    });

    test(
      'unresolved catalog networks do not block orphan import preflight',
      () async {
        final imported = await secrets.import(
          words: words,
          language: bip39.Language.english,
        );
        final secret = (imported as Ok<Secret, SecretFailure>).value;
        await fixture.registerMnemonic(secret, unresolvedNetwork: 'unresolved');
        expect(
          await usecase.execute(
            mnemonicWords: words,
            language: bip39.Language.english,
          ),
          isA<Ok<void, ImportMnemonicFailure>>(),
        );
        await fixture.registerMnemonic(secret);
        expect(
          await usecase.execute(
            mnemonicWords: words,
            language: bip39.Language.english,
          ),
          isA<Err<void, ImportMnemonicFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<ImportMnemonicDuplicateFailure>(),
          ),
        );
      },
    );

    test('refuses orphan recovery from an incomplete selection', () async {
      final matching = await secrets.import(
        words: words,
        language: bip39.Language.english,
      );
      final unrelated = await secrets.import(
        words: words,
        language: bip39.Language.english,
        passphrase: 'unrelated test wallet',
      );
      await fixture.registerMnemonic(
        (matching as Ok<Secret, SecretFailure>).value,
        internalDescriptor: 'unreadable',
      );
      await fixture.registerMnemonic(
        (unrelated as Ok<Secret, SecretFailure>).value,
      );

      expect(
        await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        ),
        isA<Err<void, ImportMnemonicFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ImportMnemonicUnexpectedFailure>(),
        ),
      );
    });

    test('refuses to decide when the wallet inventory is locked', () async {
      final imported = await secrets.import(
        words: words,
        language: bip39.Language.english,
      );
      final secret = (imported as Ok<Secret, SecretFailure>).value;
      await fixture.registerMnemonic(secret);
      fixture.inventory.lock();

      expect(
        await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        ),
        isA<Err<void, ImportMnemonicFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ImportMnemonicUnexpectedFailure>(),
        ),
      );
    });

    test('a passphrase makes a different secret, not a duplicate', () async {
      expect(
        await secrets.import(words: words, language: bip39.Language.english),
        isA<Ok<Secret, SecretFailure>>(),
      );

      final result = await usecase.execute(
        mnemonicWords: words,
        passphrase: 'TREZOR',
        language: bip39.Language.english,
      );

      expect(result, isA<Ok<void, ImportMnemonicFailure>>());
    });

    test(
      'a keystore error is unexpected, and carries no stored text',
      () async {
        const sentinel = 'SYNTHETIC_KEYSTORE_SENTINEL';
        expect(
          await secrets.import(words: words, language: bip39.Language.english),
          isA<Ok<Secret, SecretFailure>>(),
        );
        // contains now reads and compares the stored seed, so every retry must fail.
        storage.scripted.addAll(List.filled(5, Exception(sentinel)));

        final result = await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        );

        final failure = (result as Err).failure;
        expect(failure, isA<ImportMnemonicUnexpectedFailure>());
        // The package reports a foreign exception by type; the message it wrote never reaches this layer, so neither does anything the keystore held.
        expect(failure.logMessage, isNot(contains(sentinel)));
      },
    );
  });
}
