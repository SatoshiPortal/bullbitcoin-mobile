import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:unorm_dart/unorm_dart.dart' show nfc;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

/// These run the real package against an in-memory keystore installed at the plugin's own seam, so duplicate detection uses the production fingerprint derivation.
class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Settings extends Mock implements SettingsRepository {}

class _Row extends Mock implements WalletMetadataModel {}

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
  late _Metadata metadata;

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    metadata = _Metadata();
    final settings = _Settings();
    when(() => metadata.fetchAll()).thenAnswer((_) async => []);
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    usecase = CheckDuplicateMnemonicUsecase(
      secrets: secrets,
      metadata: metadata,
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
        final row = _Row();
        when(() => row.masterFingerprint).thenReturn(secret.id.hex);
        when(() => row.networkCode).thenReturn('bitcoinMainnet');
        when(() => metadata.fetchAll()).thenAnswer((_) async => [row]);
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
        await usecase.execute(mnemonicWords: words),
        isA<Ok<void, ImportMnemonicFailure>>(),
      );
    });

    test('allows an orphan secret to be retried', () async {
      expect(
        await secrets.import(words: words),
        isA<Ok<Secret, SecretFailure>>(),
      );

      final result = await usecase.execute(mnemonicWords: words);

      expect(result, isA<Ok<void, ImportMnemonicFailure>>());
    });

    test('rejects a referenced secret only on the target network', () async {
      expect(await secrets.import(words: words), isA<Ok>());
      final row = _Row();
      when(() => row.masterFingerprint).thenReturn('73c5da0a');
      when(() => row.id).thenReturn('wpkh([73c5da0a/84h/0h/0h])');
      when(() => row.networkCode).thenReturn('bitcoinMainnet');
      when(() => metadata.fetchAll()).thenAnswer((_) async => [row]);
      expect(
        await usecase.execute(mnemonicWords: words),
        isA<Err<void, ImportMnemonicFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ImportMnemonicDuplicateFailure>(),
        ),
      );
      when(() => row.id).thenReturn('wpkh([73c5da0a/84h/1h/0h])');
      when(() => row.networkCode).thenReturn('bitcoinTestnet');
      expect(
        await usecase.execute(mnemonicWords: words),
        isA<Ok<void, ImportMnemonicFailure>>(),
      );
    });

    test(
      'unresolved catalog networks do not block orphan import preflight',
      () async {
        expect(await secrets.import(words: words), isA<Ok>());
        final invalid = _Row();
        when(() => invalid.masterFingerprint).thenReturn('73c5da0a');
        when(() => invalid.id).thenReturn('invalid origin');
        when(() => invalid.networkCode).thenReturn('unresolved');
        when(() => metadata.fetchAll()).thenAnswer((_) async => [invalid]);
        expect(
          await usecase.execute(mnemonicWords: words),
          isA<Ok<void, ImportMnemonicFailure>>(),
        );
        final valid = _Row();
        when(() => valid.masterFingerprint).thenReturn('73c5da0a');
        when(() => valid.id).thenReturn('wpkh([73c5da0a/84h/0h/0h])');
        when(() => valid.networkCode).thenReturn('bitcoinMainnet');
        when(
          () => metadata.fetchAll(),
        ).thenAnswer((_) async => [invalid, valid]);
        expect(
          await usecase.execute(mnemonicWords: words),
          isA<Err<void, ImportMnemonicFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<ImportMnemonicDuplicateFailure>(),
          ),
        );
      },
    );

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
