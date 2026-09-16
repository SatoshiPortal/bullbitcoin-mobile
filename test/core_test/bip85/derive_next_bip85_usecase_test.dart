import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockBip85Repository extends Mock implements Bip85Repository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

/// Failure paths of the three BIP85 usecases.
///
/// The derivation itself moved into `secrets` — the xprv no longer leaves the package — so what is left here is the orchestration: which wallet, which index, and what each failure is called. The values are pinned by the package's `derivation_vectors_test.dart`.
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

  late _MockBip85Repository bip85Repository;
  late _MockWalletRepository walletRepository;
  late _MockSettingsRepository settingsRepository;
  late Secrets secrets;
  late Wallet defaultWallet;

  Wallet walletFor(String fingerprint) => Wallet(
    origin: 'test-id',
    label: 'Test',
    network: Network.bitcoinMainnet,
    isDefault: true,
    masterFingerprint: fingerprint,
    xpubFingerprint: fingerprint,
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'desc',
    internalPublicDescriptor: 'desc',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );

  void stubWallets(List<Wallet> wallets) {
    when(
      () => walletRepository.getWallets(
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => wallets);
  }

  setUpAll(() {
    registerFallbackValue(Bip85Application.hex);
    registerFallbackValue(bip39.MnemonicLength.words12);
  });

  setUp(() async {
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    final stored =
        (await secrets.import(words: words)) as Ok<Secret, SecretFailure>;
    defaultWallet = walletFor(stored.value.id.hex);

    bip85Repository = _MockBip85Repository();
    walletRepository = _MockWalletRepository();
    settingsRepository = _MockSettingsRepository();
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
  });

  group('DeriveNextBip85MnemonicFromDefaultWalletUsecase', () {
    late DeriveNextBip85MnemonicFromDefaultWalletUsecase usecase;

    setUp(() {
      usecase = DeriveNextBip85MnemonicFromDefaultWalletUsecase(
        bip85Repository: bip85Repository,
        walletRepository: walletRepository,
        secrets: secrets,
        settingsRepository: settingsRepository,
      );
    });

    test('no default wallet is its own failure, with no message', () async {
      stubWallets([]);

      final failure = ((await usecase.execute()) as Err).failure;

      expect(failure, isA<Bip85NoDefaultWalletFailure>());
      expect(failure.logMessage, isNull);
    });

    test('a wallet repository that throws is unexpected', () async {
      when(
        () => walletRepository.getWallets(
          onlyDefaults: any(named: 'onlyDefaults'),
          onlyBitcoin: any(named: 'onlyBitcoin'),
          environment: any(named: 'environment'),
        ),
      ).thenThrow(Exception('internal db error with secret path /data/user'));

      final failure = ((await usecase.execute()) as Err).failure;

      expect(failure, isA<Bip85UnexpectedFailure>());
    });

    test('derives and records at the allocated index', () async {
      stubWallets([defaultWallet]);
      when(
        () => bip85Repository.fetchNextIndexForApplication(any()),
      ).thenAnswer((_) async => const Ok(3));
      when(
        () => bip85Repository.recordMnemonic(
          xprvFingerprint: any(named: 'xprvFingerprint'),
          length: any(named: 'length'),
          index: any(named: 'index'),
          alias: any(named: 'alias'),
        ),
      ).thenAnswer((_) async => const Ok("83696968'/39'/0'/12'/3'"));

      final result = await usecase.execute();

      expect(result, isA<Ok>());
      // Recorded against the secret that derived it, at the index the repository allocated.
      verify(
        () => bip85Repository.recordMnemonic(
          xprvFingerprint: defaultWallet.masterFingerprint,
          length: any(named: 'length'),
          index: 3,
          alias: any(named: 'alias'),
        ),
      ).called(1);
    });
  });

  group('DeriveNextBip85HexFromDefaultWalletUsecase', () {
    late DeriveNextBip85HexFromDefaultWalletUsecase usecase;

    setUp(() {
      usecase = DeriveNextBip85HexFromDefaultWalletUsecase(
        bip85Repository: bip85Repository,
        walletRepository: walletRepository,
        secrets: secrets,
        settingsRepository: settingsRepository,
      );
    });

    test('no default wallet is its own failure', () async {
      stubWallets([]);

      expect(
        ((await usecase.execute(length: 30)) as Err).failure,
        isA<Bip85NoDefaultWalletFailure>(),
      );
    });

    test(
      'a wallet with no stored secret is unexpected, not "no wallet"',
      () async {
        stubWallets([walletFor('00000000')]);

        final failure = ((await usecase.execute(length: 30)) as Err).failure;

        expect(failure, isA<Bip85UnexpectedFailure>());
        expect(failure, isNot(isA<Bip85NoDefaultWalletFailure>()));
      },
    );

    test('an index allocation failure is forwarded as-is', () async {
      stubWallets([defaultWallet]);
      when(
        () => bip85Repository.fetchNextIndexForApplication(any()),
      ).thenAnswer((_) async => const Err(Bip85StorageFailure('no index')));

      expect(
        ((await usecase.execute(length: 30)) as Err).failure,
        isA<Bip85StorageFailure>(),
      );
    });
  });

  group('FetchAllBip85DerivationsWithEntropyUsecase', () {
    late FetchAllBip85DerivationsWithEntropyUsecase usecase;

    setUp(() {
      usecase = FetchAllBip85DerivationsWithEntropyUsecase(
        bip85Repository: bip85Repository,
        walletRepository: walletRepository,
        settingsRepository: settingsRepository,
        secrets: secrets,
      );
    });

    test('no default wallet is its own failure', () async {
      stubWallets([]);

      expect(
        ((await usecase.execute()) as Err).failure,
        isA<Bip85NoDefaultWalletFailure>(),
      );
    });

    test('a wallet repository that throws is unexpected', () async {
      when(
        () => walletRepository.getWallets(
          onlyDefaults: any(named: 'onlyDefaults'),
          onlyBitcoin: any(named: 'onlyBitcoin'),
          environment: any(named: 'environment'),
        ),
      ).thenThrow(Exception('internal db error with secret path /data/user'));

      expect(
        ((await usecase.execute()) as Err).failure,
        isA<Bip85UnexpectedFailure>(),
      );
    });

    group('a persisted path is checked against its row, not trusted', () {
      Bip85DerivationEntity row(String path, Bip85Application app, int index) =>
          Bip85DerivationEntity(
            path: path,
            xprvFingerprint: defaultWallet.masterFingerprint,
            alias: null,
            status: Bip85Status.active,
            application: app,
            index: index,
          );

      Future<int> derived(Bip85DerivationEntity e) async {
        stubWallets([defaultWallet]);
        when(() => bip85Repository.fetchAll()).thenAnswer((_) async => Ok([e]));
        return ((await usecase.execute()) as Ok).value.length;
      }

      test('a well-formed HEX row is derived', () async {
        expect(
          await derived(row("128169'/32'/0'", Bip85Application.hex, 0)),
          1,
        );
      });

      test('an unhardened path is skipped, not derived as hardened', () async {
        expect(await derived(row("128169/32/0", Bip85Application.hex, 0)), 0);
      });

      test('a BIP39 path tagged HEX is skipped, not served as HEX', () async {
        expect(await derived(row("39'/32'/0'", Bip85Application.hex, 0)), 0);
      });

      test('an index that disagrees with the row is skipped', () async {
        expect(
          await derived(row("128169'/32'/5'", Bip85Application.hex, 0)),
          0,
        );
      });
    });

    test('rows of another root key are not re-derived from this one', () async {
      stubWallets([defaultWallet]);
      when(() => bip85Repository.fetchAll()).thenAnswer(
        (_) async => Ok([
          Bip85DerivationEntity(
            path: "128169'/32'/0'",
            xprvFingerprint: 'ffffffff',
            alias: null,
            status: Bip85Status.active,
            application: Bip85Application.hex,
            index: 0,
          ),
        ]),
      );

      final result = await usecase.execute();

      expect((result as Ok).value, isEmpty);
    });
  });
}
