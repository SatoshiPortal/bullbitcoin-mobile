import 'package:primitives/primitives.dart' show ScriptType;
import 'package:startup/testing.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide ScriptType;
import 'package:primitives/primitives.dart' as primitives;
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart' show BitcoinRecoveryWallet;
import 'package:secrets/testing.dart';

abstract interface class _RecoveryCatalog {
  Future<Result<List<BitcoinRecoveryWallet>, SecretFailure>> getWallets();
}

class _MockWalletRepository extends Mock implements _RecoveryCatalog {}

/// The words the default wallets were built from, and another wallet's.
const _missing = [
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
const _other = [
  'legal',
  'winner',
  'thank',
  'year',
  'wave',
  'sausage',
  'worth',
  'useful',
  'legal',
  'winner',
  'thank',
  'yellow',
];
const _missingFingerprint = '73c5da0a';
const _zoo = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];
const _zooFingerprint = '3f635a63';
const _zooZpub =
    'zpub6rD5AGSXPTDMSnpmczjENMT3NvVF7q5MySww6uxitUsBYgkZLeBywrcwUWhW5YkeY2aS7xc45APPgfA6s6wWfG2gnfABq6TDz9zqeMu2JCY';

void main() {
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late _MockWalletRepository wallets;
  late RestoreMissingDefaultSecretUsecase usecase;

  BitcoinRecoveryWallet localWallet(
    String fingerprint, {
    String external = 'desc',
    String internal = 'desc',
    bool isDefault = false,
  }) => BitcoinRecoveryWallet(
    id: 'origin-$fingerprint',
    network: BitcoinNetwork.mainnet,
    fingerprint: Fingerprint(fingerprint),
    scriptType: ScriptType.bip84,
    isDefault: isDefault,
    descriptors: (external: external, internal: internal),
  );

  Future<BitcoinRecoveryWallet> realWallet(
    String fingerprint,
    List<String> words, [
    String passphrase = '',
    bool isDefault = true,
  ]) async {
    final result = await secrets.preview.bitcoinDescriptors(
      words: words,
      passphrase: passphrase,
      network: primitives.BitcoinNetwork.mainnet,
      scriptTypes: {primitives.ScriptType.bip84},
      language: Language.english,
    );
    final descriptors =
        (result as Ok<Map<primitives.ScriptType, Descriptors>, SecretFailure>)
            .value[primitives.ScriptType.bip84];
    if (descriptors == null) throw StateError('missing descriptors');
    return localWallet(
      fingerprint,
      external: descriptors.external,
      internal: descriptors.internal,
      isDefault: isDefault,
    );
  }

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp',
    );
    wallets = _MockWalletRepository();
    final wallet = await realWallet(_missingFingerprint, _missing);
    when(() => wallets.getWallets()).thenAnswer(
      (_) async => Ok<List<BitcoinRecoveryWallet>, SecretFailure>([wallet]),
    );
    usecase = RestoreMissingDefaultSecretUsecase(
      secrets: secrets,
      recoveryWallets: wallets.getWallets,
    );
  });

  BitcoinRecoveryWallet zooDefault({bool hardenedWithH = false}) {
    // Published zoo vector, independently pinned in native integration tests;
    // no call to the preview under test constructs this oracle.
    final xpub = primitives.XpubType.xpub.reencode(_zooZpub);
    final path = hardenedWithH ? '84h/0h/0h' : "84'/0'/0'";
    return BitcoinRecoveryWallet(
      id: 'default-zoo',
      network: BitcoinNetwork.mainnet,
      fingerprint: Fingerprint(_zooFingerprint),
      scriptType: ScriptType.bip84,
      isDefault: true,
      descriptors: (
        external: 'wpkh([$_zooFingerprint/$path]$xpub/0/*)',
        internal: 'wpkh([$_zooFingerprint/$path]$xpub/1/*)',
      ),
    );
  }

  test(
    'accepts equivalent hardened-path notation on the default wallet',
    () async {
      when(() => wallets.getWallets()).thenAnswer(
        (_) async => Ok<List<BitcoinRecoveryWallet>, SecretFailure>([
          zooDefault(hardenedWithH: true),
        ]),
      );
      expect(
        await usecase.execute(
          language: Language.english,
          expectedFingerprint: _zooFingerprint,
          words: _zoo,
        ),
        isA<Ok<void, AppStartupFailure>>(),
      );
      expect(storage.entries.keys, contains('seed_$_zooFingerprint'));
    },
  );

  test(
    'a secondary wallet with the same fingerprint cannot veto its default',
    () async {
      when(() => wallets.getWallets()).thenAnswer(
        (_) async => Ok<List<BitcoinRecoveryWallet>, SecretFailure>([
          zooDefault(),
          localWallet(_zooFingerprint),
        ]),
      );
      expect(
        await usecase.execute(
          language: Language.english,
          expectedFingerprint: _zooFingerprint,
          words: _zoo,
        ),
        isA<Ok<void, AppStartupFailure>>(),
      );
      expect(storage.entries.keys, contains('seed_$_zooFingerprint'));
    },
  );

  test('wallet id selects the intended default across two networks', () async {
    const tpub =
        'tpubDCgYNDYFCZpc5H8LExm81BQd8YcpJndx14YXjFV5XZrFxexwZKMVAycjDvmdLJELb6NgeVAM4UyGbqVqqdATXQh5FnYkS4C9DkzmFc9A86Z';
    final mainnet = zooDefault();
    final testnet = BitcoinRecoveryWallet(
      id: 'default-testnet',
      network: BitcoinNetwork.testnet,
      fingerprint: mainnet.fingerprint,
      scriptType: mainnet.scriptType,
      isDefault: mainnet.isDefault,
      descriptors: (
        external: "wpkh([$_zooFingerprint/84'/1'/0']$tpub/0/*)",
        internal: "wpkh([$_zooFingerprint/84'/1'/0']$tpub/1/*)",
      ),
    );
    when(() => wallets.getWallets()).thenAnswer(
      (_) async =>
          Ok<List<BitcoinRecoveryWallet>, SecretFailure>([mainnet, testnet]),
    );
    expect(
      await usecase.execute(
        language: Language.english,
        expectedFingerprint: _zooFingerprint,
        words: _zoo,
      ),
      isA<Err<void, AppStartupFailure>>(),
    );
    expect(storage.entries, isEmpty);
    expect(
      await usecase.execute(
        language: Language.english,
        expectedFingerprint: _zooFingerprint,
        expectedWalletId: testnet.id,
        words: _zoo,
      ),
      isA<Ok<void, AppStartupFailure>>(),
    );
    expect(storage.entries.keys, contains('seed_$_zooFingerprint'));
  });

  test(
    'a selected secondary wallet cannot authorize the missing default',
    () async {
      final secondary = _copyRecovery(
        zooDefault(),
        id: 'secondary',
        isDefault: false,
      );
      when(() => wallets.getWallets()).thenAnswer(
        (_) async => Ok<List<BitcoinRecoveryWallet>, SecretFailure>([
          zooDefault(),
          secondary,
        ]),
      );
      expect(
        await usecase.execute(
          language: Language.english,
          expectedFingerprint: _zooFingerprint,
          expectedWalletId: secondary.id,
          words: _zoo,
        ),
        isA<Err<void, AppStartupFailure>>(),
      );
      expect(storage.entries, isEmpty);
    },
  );

  test(
    'descriptor origin, branch and checksum are verified before writing',
    () async {
      final base = zooDefault();
      for (final invalid in [
        _copyRecovery(
          base,
          external: base.descriptors.external.replaceFirst(
            _zooFingerprint,
            'ffffffff',
          ),
        ),
        _copyRecovery(base, internal: base.descriptors.external),
        _copyRecovery(base, external: '${base.descriptors.external}#aaaaaaaa'),
      ]) {
        when(() => wallets.getWallets()).thenAnswer(
          (_) async =>
              Ok<List<BitcoinRecoveryWallet>, SecretFailure>([invalid]),
        );
        expect(
          await usecase.execute(
            language: Language.english,
            expectedFingerprint: _zooFingerprint,
            expectedWalletId: invalid.id,
            words: _zoo,
          ),
          isA<Err<void, AppStartupFailure>>(),
        );
        expect(storage.entries, isEmpty);
      }
    },
  );

  test('restores a passphrase wallet only with its exact passphrase', () async {
    const passphrase = ' Mixed Case ';
    final created = await secrets.import(
      words: _missing,
      passphrase: passphrase,
      language: Language.english,
    );
    final fingerprint = (created as Ok<Secret, SecretFailure>).value.id.hex;
    final wallet = await realWallet(fingerprint, _missing, passphrase);
    when(() => wallets.getWallets()).thenAnswer(
      (_) async => Ok<List<BitcoinRecoveryWallet>, SecretFailure>([wallet]),
    );
    expect(
      await secrets.trash(Fingerprint(fingerprint)),
      isA<Ok<void, SecretFailure>>(),
    );

    final wrong = await usecase.execute(
      language: Language.english,
      expectedFingerprint: fingerprint,
      words: _missing,
      passphrase: passphrase.trim(),
    );
    expect(wrong, isA<Err<void, AppStartupFailure>>());
    expect(storage.entries, isEmpty);

    final restored = await usecase.execute(
      language: Language.english,
      expectedFingerprint: fingerprint,
      words: _missing,
      passphrase: passphrase,
    );
    expect(restored, isA<Ok<void, AppStartupFailure>>());
    expect(storage.entries.keys, contains('seed_$fingerprint'));
  });

  test(
    'refuses matching fingerprint when public descriptors disagree',
    () async {
      when(() => wallets.getWallets()).thenAnswer(
        (_) async => Ok<List<BitcoinRecoveryWallet>, SecretFailure>([
          localWallet(_missingFingerprint),
        ]),
      );
      final result = await usecase.execute(
        language: Language.english,
        expectedFingerprint: _missingFingerprint,
        words: _missing,
      );
      expect(result, isA<Err<void, AppStartupFailure>>());
      expect(storage.entries, isEmpty);
    },
  );

  test('a second wallet with the same fingerprint cannot mask a descriptor mismatch', () async {
    final matching = await realWallet(_missingFingerprint, _missing, '', false);
    when(() => wallets.getWallets()).thenAnswer(
      (_) async => Ok<List<BitcoinRecoveryWallet>, SecretFailure>([
        matching,
        localWallet(_missingFingerprint, isDefault: true),
      ]),
    );
    final result = await usecase.execute(
      language: Language.english,
      expectedFingerprint: _missingFingerprint,
      words: _missing,
    );
    expect(result, isA<Err<void, AppStartupFailure>>());
    expect(storage.entries, isEmpty);
  });

  test('refuses to write when no Bitcoin descriptor is available', () async {
    when(() => wallets.getWallets()).thenAnswer(
      (_) async => const Ok<List<BitcoinRecoveryWallet>, SecretFailure>([]),
    );
    final result = await usecase.execute(
      language: Language.english,
      expectedFingerprint: _missingFingerprint,
      words: _missing,
    );
    expect(result, isA<Err<void, AppStartupFailure>>());
    expect(storage.entries, isEmpty);
  });

  test('stores the words of the missing wallet', () async {
    final result = await usecase.execute(
      language: Language.english,
      expectedFingerprint: _missingFingerprint,
      words: _missing,
    );

    expect(result, isA<Ok<void, AppStartupFailure>>());
    expect(storage.entries.keys, contains('seed_$_missingFingerprint'));
  });

  test("refuses another wallet's words and leaves nothing behind", () async {
    final result = await usecase.execute(
      language: Language.english,
      expectedFingerprint: _missingFingerprint,
      words: _other,
    );

    expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
    expect(storage.entries, isEmpty);
  });

  test(
    "refuses another wallet's words without writing, so no cleanup can fail",
    () async {
      // A write would succeed and its undo would fail: only a check made
      // before the write keeps the refused words out of the keystore.
      storage = FakeSecureStoragePlatform(
        scriptedWrites: [null, FakeSecureStoragePlatform.lockedError],
      )..install();

      final result = await usecase.execute(
        language: Language.english,
        expectedFingerprint: _missingFingerprint,
        words: _other,
      );

      expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
      expect(storage.entries, isEmpty);
      expect(
        await secrets.import(words: _other, language: Language.english),
        isA<Ok<Secret, SecretFailure>>(),
      );
    },
  );

  test("keeps another wallet's words when a wallet uses them", () async {
    final other = (await secrets.import(
      words: _other,
      language: Language.english,
    )) as Ok<Secret, SecretFailure>;
    final otherFingerprint = other.value.id.hex;
    expect(
      await secrets.trash(Fingerprint(otherFingerprint)),
      isA<Ok<void, SecretFailure>>(),
    );
    final wallet = await realWallet(otherFingerprint, _other, '', false);
    final expectedWallet = await realWallet(_missingFingerprint, _missing);
    when(() => wallets.getWallets()).thenAnswer(
      (_) async => Ok<List<BitcoinRecoveryWallet>, SecretFailure>([
        expectedWallet,
        wallet,
      ]),
    );

    final result = await usecase.execute(
      language: Language.english,
      expectedFingerprint: _missingFingerprint,
      expectedWalletId: expectedWallet.id,
      words: _other,
    );

    expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
    expect(storage.entries.keys, contains('seed_$otherFingerprint'));
  });

  test('refuses words that are not a recovery phrase', () async {
    final result = await usecase.execute(
      language: Language.english,
      expectedFingerprint: _missingFingerprint,
      words: [..._missing.take(11), 'abandon'],
    );

    expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
    expect(storage.entries, isEmpty);
  });

  group('a default wallet restored from a French phrase', () {
    // A generated French phrase, never a real wallet's.
    final french = bip39.Mnemonic(
      List<int>.generate(16, (i) => i * 7 + 1),
      Language.french,
    ).words;
    late String fingerprint;

    setUp(() async {
      final imported = await secrets.import(
        words: french,
        language: Language.french,
      );
      fingerprint = (imported as Ok<Secret, SecretFailure>).value.id.hex;
      storage.entries.clear();
      final preview = await secrets.preview.bitcoinDescriptors(
        words: french,
        language: Language.french,
        network: primitives.BitcoinNetwork.mainnet,
        scriptTypes: {primitives.ScriptType.bip84},
      );
      final descriptors =
          (preview
                  as Ok<Map<primitives.ScriptType, Descriptors>, SecretFailure>)
              .value[primitives.ScriptType.bip84];
      if (descriptors == null) throw StateError('missing descriptors');
      final wallet = localWallet(
        fingerprint,
        external: descriptors.external,
        internal: descriptors.internal,
        isDefault: true,
      );
      when(() => wallets.getWallets()).thenAnswer(
        (_) async => Ok<List<BitcoinRecoveryWallet>, SecretFailure>([wallet]),
      );
    });

    test('is stored back in French', () async {
      final result = await usecase.execute(
        language: Language.french,
        expectedFingerprint: fingerprint,
        words: french,
      );

      expect(result, isA<Ok<void, AppStartupFailure>>());
      final stored = await secrets.fetch(Fingerprint(fingerprint));
      expect(
        (stored as Ok<Secret, SecretFailure>).value.info.language,
        Language.french,
      );
    });

    test('is refused when its words are read as English', () async {
      final result = await usecase.execute(
        language: Language.english,
        expectedFingerprint: fingerprint,
        words: french,
      );

      expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
      expect(storage.entries, isEmpty);
    });

    test('is refused with a broken checksum', () async {
      final words = [...french];
      words[11] = words[11] == 'abaisser' ? 'abandon' : 'abaisser';
      expect(
        () => bip39.Mnemonic.fromWords(words: words, language: Language.french),
        throwsA(isA<bip39.MnemonicException>()),
      );

      final result = await usecase.execute(
        language: Language.french,
        expectedFingerprint: fingerprint,
        words: words,
      );

      expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
      expect(storage.entries, isEmpty);
    });
  });
}

BitcoinRecoveryWallet _copyRecovery(
  BitcoinRecoveryWallet wallet, {
  String? id,
  bool? isDefault,
  String? external,
  String? internal,
}) => BitcoinRecoveryWallet(
  id: id ?? wallet.id,
  network: wallet.network,
  fingerprint: wallet.fingerprint,
  scriptType: wallet.scriptType,
  isDefault: isDefault ?? wallet.isDefault,
  descriptors: (
    external: external ?? wallet.descriptors.external,
    internal: internal ?? wallet.descriptors.internal,
  ),
);
