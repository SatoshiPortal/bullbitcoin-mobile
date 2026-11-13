import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:unorm_dart/unorm_dart.dart' show nfc;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

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
  late _MockWalletRepository wallets;
  late CheckDuplicateMnemonicUsecase usecase;

  // The fingerprint of `words`, without a passphrase.
  const fingerprint = '73c5da0a';

  Wallet signingWallet(String masterFingerprint, {bool signsLocally = true}) {
    final wallet = _MockWallet();
    when(() => wallet.signsLocally).thenReturn(signsLocally);
    when(() => wallet.masterFingerprint).thenReturn(masterFingerprint);
    return wallet;
  }

  void walletsAre(List<Wallet> list) => when(
    () => wallets.getWallets(),
  ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>(list));

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    wallets = _MockWalletRepository();
    walletsAre([]);
    usecase = CheckDuplicateMnemonicUsecase(
      secrets: secrets,
      walletRepository: wallets,
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
        final stored = await secrets.import(words: words, language: language);
        expect(stored, isA<Ok<Secret, SecretFailure>>());
        final secret = (stored as Ok<Secret, SecretFailure>).value;
        expect(
          await usecase.execute(mnemonicWords: words, language: language),
          isA<Ok<void, ImportMnemonicFailure>>(),
        );
        walletsAre([signingWallet(secret.id.hex)]);
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

    test(
      'returns Err(duplicate) once a wallet signs with the same mnemonic',
      () async {
        expect(
          await secrets.import(words: words),
          isA<Ok<Secret, SecretFailure>>(),
        );
        walletsAre([signingWallet(fingerprint)]);

        final result = await usecase.execute(mnemonicWords: words);

        expect((result as Err).failure, isA<ImportMnemonicDuplicateFailure>());
      },
    );

    test(
      'a stored mnemonic no wallet signs with is not a duplicate: the import reuses it',
      () async {
        expect(
          await secrets.import(words: words),
          isA<Ok<Secret, SecretFailure>>(),
        );
        // A watch-only wallet with the same origin holds no seed.
        walletsAre([signingWallet(fingerprint, signsLocally: false)]);

        expect(
          await usecase.execute(mnemonicWords: words),
          isA<Ok<void, ImportMnemonicFailure>>(),
        );
      },
    );

    test(
      'when the wallets cannot be listed, a stored mnemonic is a duplicate',
      () async {
        expect(
          await secrets.import(words: words),
          isA<Ok<Secret, SecretFailure>>(),
        );
        when(() => wallets.getWallets()).thenAnswer(
          (_) async => const Err<List<Wallet>, WalletFailure>(
            WalletStorageFailure('unavailable'),
          ),
        );

        final result = await usecase.execute(mnemonicWords: words);

        expect((result as Err).failure, isA<ImportMnemonicDuplicateFailure>());
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
