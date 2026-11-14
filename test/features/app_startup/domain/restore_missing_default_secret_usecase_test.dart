import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/restore_missing_default_secret_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide Network, ScriptType;
import 'package:primitives/primitives.dart' as primitives;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

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

  Wallet localWallet(
    String fingerprint, {
    String external = 'desc',
    String internal = 'desc',
    bool isDefault = false,
  }) => Wallet(
    origin: 'origin-$fingerprint',
    label: 'Test',
    network: Network.bitcoinMainnet,
    isDefault: isDefault,
    masterFingerprint: fingerprint,
    xpubFingerprint: fingerprint,
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: external,
    internalPublicDescriptor: internal,
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );

  Future<Wallet> realWallet(
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
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    wallets = _MockWalletRepository();
    final wallet = await realWallet(_missingFingerprint, _missing);
    when(
      () => wallets.getWallets(),
    ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([wallet]));
    usecase = RestoreMissingDefaultSecretUsecase(
      secrets: secrets,
      walletRepository: wallets,
    );
  });

  Wallet zooDefault({bool hardenedWithH = false}) {
    // Published zoo vector, independently pinned in native integration tests;
    // no call to the preview under test constructs this oracle.
    final xpub = primitives.XpubType.xpub.reencode(_zooZpub);
    final path = hardenedWithH ? '84h/0h/0h' : "84'/0'/0'";
    return Wallet(
      origin: 'default-zoo',
      label: 'Default',
      network: Network.bitcoinMainnet,
      isDefault: true,
      masterFingerprint: _zooFingerprint,
      xpubFingerprint: _zooFingerprint,
      scriptType: ScriptType.bip84,
      xpub: xpub,
      externalPublicDescriptor: 'wpkh([$_zooFingerprint/$path]$xpub/0/*)',
      internalPublicDescriptor: 'wpkh([$_zooFingerprint/$path]$xpub/1/*)',
      signer: SignerEntity.local,
      signerDevice: null,
      balanceSat: BigInt.zero,
    );
  }

  test(
    'accepts equivalent hardened-path notation on the default wallet',
    () async {
      when(() => wallets.getWallets()).thenAnswer(
        (_) async =>
            Ok<List<Wallet>, WalletFailure>([zooDefault(hardenedWithH: true)]),
      );
      expect(
        await usecase.execute(
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
        (_) async => Ok<List<Wallet>, WalletFailure>([
          zooDefault(),
          localWallet(_zooFingerprint),
        ]),
      );
      expect(
        await usecase.execute(
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
    final testnet = mainnet.copyWith(
      origin: 'default-testnet',
      network: Network.bitcoinTestnet,
      xpub: tpub,
      externalPublicDescriptor: "wpkh([$_zooFingerprint/84'/1'/0']$tpub/0/*)",
      internalPublicDescriptor: "wpkh([$_zooFingerprint/84'/1'/0']$tpub/1/*)",
    );
    when(() => wallets.getWallets()).thenAnswer(
      (_) async => Ok<List<Wallet>, WalletFailure>([mainnet, testnet]),
    );
    expect(
      await usecase.execute(expectedFingerprint: _zooFingerprint, words: _zoo),
      isA<Err<void, AppStartupFailure>>(),
    );
    expect(storage.entries, isEmpty);
    expect(
      await usecase.execute(
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
      final secondary = zooDefault().copyWith(
        isDefault: false,
        origin: 'secondary',
      );
      when(() => wallets.getWallets()).thenAnswer(
        (_) async => Ok<List<Wallet>, WalletFailure>([zooDefault(), secondary]),
      );
      expect(
        await usecase.execute(
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
        base.copyWith(
          externalPublicDescriptor: base.externalPublicDescriptor.replaceFirst(
            _zooFingerprint,
            'ffffffff',
          ),
        ),
        base.copyWith(internalPublicDescriptor: base.externalPublicDescriptor),
        base.copyWith(
          externalPublicDescriptor: '${base.externalPublicDescriptor}#aaaaaaaa',
        ),
      ]) {
        when(
          () => wallets.getWallets(),
        ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([invalid]));
        expect(
          await usecase.execute(
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
    );
    final fingerprint = (created as Ok<Secret, SecretFailure>).value.id.hex;
    final wallet = await realWallet(fingerprint, _missing, passphrase);
    when(
      () => wallets.getWallets(),
    ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([wallet]));
    expect(
      await secrets.trash(Fingerprint(fingerprint)),
      isA<Ok<void, SecretFailure>>(),
    );

    final wrong = await usecase.execute(
      expectedFingerprint: fingerprint,
      words: _missing,
      passphrase: passphrase.trim(),
    );
    expect(wrong, isA<Err<void, AppStartupFailure>>());
    expect(storage.entries, isEmpty);

    final restored = await usecase.execute(
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
        (_) async =>
            Ok<List<Wallet>, WalletFailure>([localWallet(_missingFingerprint)]),
      );
      final result = await usecase.execute(
        expectedFingerprint: _missingFingerprint,
        words: _missing,
      );
      expect(result, isA<Err<void, AppStartupFailure>>());
      expect(storage.entries, isEmpty);
    },
  );

  test(
    'a second wallet with the same fingerprint cannot mask a descriptor mismatch',
    () async {
      final matching = await realWallet(
        _missingFingerprint,
        _missing,
        '',
        false,
      );
      when(() => wallets.getWallets()).thenAnswer(
        (_) async => Ok<List<Wallet>, WalletFailure>([
          matching,
          localWallet(_missingFingerprint, isDefault: true),
        ]),
      );
      final result = await usecase.execute(
        expectedFingerprint: _missingFingerprint,
        words: _missing,
      );
      expect(result, isA<Err<void, AppStartupFailure>>());
      expect(storage.entries, isEmpty);
    },
  );

  test('refuses to write when no Bitcoin descriptor is available', () async {
    when(
      () => wallets.getWallets(),
    ).thenAnswer((_) async => const Ok<List<Wallet>, WalletFailure>([]));
    final result = await usecase.execute(
      expectedFingerprint: _missingFingerprint,
      words: _missing,
    );
    expect(result, isA<Err<void, AppStartupFailure>>());
    expect(storage.entries, isEmpty);
  });

  test('stores the words of the missing wallet', () async {
    final result = await usecase.execute(
      expectedFingerprint: _missingFingerprint,
      words: _missing,
    );

    expect(result, isA<Ok<void, AppStartupFailure>>());
    expect(storage.entries.keys, contains('seed_$_missingFingerprint'));
  });

  test("refuses another wallet's words and leaves nothing behind", () async {
    final result = await usecase.execute(
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
        expectedFingerprint: _missingFingerprint,
        words: _other,
      );

      expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
      expect(storage.entries, isEmpty);
      expect(
        await secrets.import(words: _other),
        isA<Ok<Secret, SecretFailure>>(),
      );
    },
  );

  test("keeps another wallet's words when a wallet uses them", () async {
    final other =
        (await secrets.import(words: _other)) as Ok<Secret, SecretFailure>;
    final otherFingerprint = other.value.id.hex;
    expect(
      await secrets.trash(Fingerprint(otherFingerprint)),
      isA<Ok<void, SecretFailure>>(),
    );
    final wallet = await realWallet(otherFingerprint, _other, '', false);
    final expectedWallet = await realWallet(_missingFingerprint, _missing);
    when(() => wallets.getWallets()).thenAnswer(
      (_) async => Ok<List<Wallet>, WalletFailure>([expectedWallet, wallet]),
    );

    final result = await usecase.execute(
      expectedFingerprint: _missingFingerprint,
      expectedWalletId: expectedWallet.id,
      words: _other,
    );

    expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
    expect(storage.entries.keys, contains('seed_$otherFingerprint'));
  });

  test('refuses words that are not a recovery phrase', () async {
    final result = await usecase.execute(
      expectedFingerprint: _missingFingerprint,
      words: [..._missing.take(11), 'abandon'],
    );

    expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
    expect(storage.entries, isEmpty);
  });
}
