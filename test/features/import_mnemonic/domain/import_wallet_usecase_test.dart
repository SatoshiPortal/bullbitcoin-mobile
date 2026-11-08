import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockCheckDuplicateMnemonicUsecase extends Mock
    implements CheckDuplicateMnemonicUsecase {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockMetadata extends Mock implements WalletMetadataDatasource {}

class _MockWallet extends Mock implements Wallet {}

class _MockMetadataRow extends Mock implements WalletMetadataModel {}

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
  final settings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
  );

  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late _MockCheckDuplicateMnemonicUsecase checkDuplicate;
  late _MockSettingsRepository settingsRepository;
  late _MockWalletRepository walletRepository;
  late ImportWalletUsecase usecase;

  setUpAll(() async {
    // `Secret` is final and cannot be mocked, so mocktail's fallback for `any(named: 'secret')` is a real one, made here and used for nothing else.
    FakeSecureStoragePlatform().install();
    final fallback = await Secrets(
      scratchDirectory: () async => '/tmp',
    ).import(words: words);
    registerFallbackValue((fallback as Ok<Secret, SecretFailure>).value);
    registerFallbackValue(Fingerprint('73c5da0a'));
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(ScriptType.bip84);
  });

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    checkDuplicate = _MockCheckDuplicateMnemonicUsecase();
    settingsRepository = _MockSettingsRepository();
    walletRepository = _MockWalletRepository();
    usecase = ImportWalletUsecase(
      checkDuplicateMnemonicUsecase: checkDuplicate,
      secrets: secrets,
      settingsRepository: settingsRepository,
      walletRepository: walletRepository,
    );
    when(
      () => checkDuplicate.execute(
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => checkDuplicate.isReferenced(any(), any()),
    ).thenAnswer((_) async => false);
    // No wallet references any seed unless a test says so.
    when(
      () => walletRepository.getWallets(),
    ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([]));
    when(() => settingsRepository.fetch()).thenAnswer((_) async => settings);
  });

  void stubCreateWallet(Future<Wallet> Function() answer) {
    when(
      () => walletRepository.createWallet(
        secret: any(named: 'secret'),
        network: any(named: 'network'),
        scriptType: any(named: 'scriptType'),
        isDefault: any(named: 'isDefault'),
        sync: any(named: 'sync'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => answer());
  }

  for (final language in bip39.Language.values) {
    test(
      'imports ${language.name} only as a non-default Bitcoin wallet',
      () async {
        final wallet = _MockWallet();
        stubCreateWallet(() async => wallet);
        final words = bip39.Mnemonic(List.filled(16, 0), language).words;
        final metadata = _MockMetadata();
        when(() => metadata.fetchAll()).thenAnswer((_) async => []);
        final usecase = ImportWalletUsecase(
          checkDuplicateMnemonicUsecase: CheckDuplicateMnemonicUsecase(
            secrets: secrets,
            metadata: metadata,
            settings: settingsRepository,
          ),
          secrets: secrets,
          settingsRepository: settingsRepository,
          walletRepository: walletRepository,
        );
        final result = await usecase.execute(
          mnemonicWords: words,
          language: language,
          label: 'Vector',
        );
        expect(result, isA<Ok<Wallet, ImportMnemonicFailure>>());
        expect((result as Ok).value, wallet);
        final entries =
            (await secrets.list() as Ok<List<SecretEntry>, SecretFailure>)
                .value;
        final secret = entries.single as Secret;
        expect(secret.info.language, language);
        verify(
          () => walletRepository.createWallet(
            secret: any(
              that: isA<Secret>().having((s) => s.id, 'id', secret.id),
              named: 'secret',
            ),
            network: Network.bitcoinMainnet,
            scriptType: ScriptType.bip84,
            isDefault: false,
            sync: false,
            label: 'Vector',
          ),
        ).called(1);
        // The first successful provisioning now references this secret on mainnet.
        final row = _MockMetadataRow();
        when(() => row.masterFingerprint).thenReturn(secret.id.hex);
        when(() => row.networkCode).thenReturn('bitcoinMainnet');
        when(() => metadata.fetchAll()).thenAnswer((_) async => [row]);
        final duplicate = await usecase.execute(
          mnemonicWords: words,
          language: language,
        );
        expect(
          (duplicate as Err).failure,
          isA<ImportMnemonicDuplicateFailure>(),
        );
        expect(
          (await secrets.exists(secret.id) as Ok<bool, SecretFailure>).value,
          isTrue,
        );
      },
    );
  }

  group('ImportWalletUsecase', () {
    test('returns Ok(wallet) and stores the secret', () async {
      final wallet = _MockWallet();
      stubCreateWallet(() async => wallet);

      final result = await usecase.execute(
        mnemonicWords: words,
        label: 'My Wallet',
      );

      expect((result as Ok).value, wallet);
      expect(
        storage.entries.keys.where((k) => k.startsWith('seed_')),
        hasLength(1),
      );
    });

    test('#2634 retries an orphan secret without replacing custody', () async {
      final wallet = _MockWallet();
      stubCreateWallet(() async => throw Exception('catalog write failed'));
      expect(await usecase.execute(mnemonicWords: words), isA<Err>());
      final keys = storage.entries.keys
          .where((k) => k.startsWith('seed_'))
          .toList();
      expect(keys, hasLength(1));
      stubCreateWallet(() async => wallet);
      expect(
        await usecase.execute(mnemonicWords: words),
        isA<Ok<Wallet, ImportMnemonicFailure>>(),
      );
      expect(storage.entries.keys.where((k) => k.startsWith('seed_')), keys);
    });

    test('a duplicate stops before anything else is touched', () async {
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => const Err(ImportMnemonicDuplicateFailure()));

      final result = await usecase.execute(mnemonicWords: words);

      expect((result as Err).failure, isA<ImportMnemonicDuplicateFailure>());
      verifyNever(() => settingsRepository.fetch());
      expect(storage.entries, isEmpty);
    });

    test(
      'a failed wallet import preserves its secret for explicit recovery',
      () async {
        stubCreateWallet(() async => throw Exception('wallet creation failed'));

        final result = await usecase.execute(mnemonicWords: words);

        expect((result as Err).failure, isA<ImportMnemonicUnexpectedFailure>());
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          hasLength(1),
          reason: 'orphan cleanup requires explicit user action',
        );
      },
    );

    test(
      'strict import rejects a referenced duplicate without cleanup',
      () async {
        when(
          () => checkDuplicate.isReferenced(any(), any()),
        ).thenAnswer((_) async => true);
        // The mocked preflight says the words are new, as it can after a stale
        // read or a concurrent storage operation. Import still rejects them.
        expect(
          await secrets.import(words: words),
          isA<Ok<Secret, SecretFailure>>(),
        );

        final result = await usecase.execute(mnemonicWords: words);

        expect((result as Err).failure, isA<ImportMnemonicDuplicateFailure>());
        verifyNever(
          () => walletRepository.createWallet(
            secret: any(named: 'secret'),
            network: any(named: 'network'),
            scriptType: any(named: 'scriptType'),
            isDefault: any(named: 'isDefault'),
            sync: any(named: 'sync'),
            label: any(named: 'label'),
          ),
        );
        verifyNever(() => walletRepository.getWallets());
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          hasLength(1),
        );
      },
    );

    test(
      'concurrent imports create one wallet and preserve its secret',
      () async {
        final wallet = _MockWallet();
        var creations = 0;
        stubCreateWallet(() async {
          creations++;
          when(
            () => checkDuplicate.isReferenced(any(), any()),
          ).thenAnswer((_) async => true);
          return wallet;
        });

        final results = await Future.wait([
          usecase.execute(mnemonicWords: words),
          usecase.execute(mnemonicWords: words),
        ]);

        expect((results.first as Ok).value, wallet);
        expect(
          (results.last as Err).failure,
          isA<ImportMnemonicDuplicateFailure>(),
        );
        expect(creations, 1);
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          hasLength(1),
        );
      },
    );

    test(
      'cleanup retains a newly stored secret referenced by a wallet',
      () async {
        final wallet = _MockWallet();
        stubCreateWallet(() async {
          when(() => wallet.signsLocally).thenReturn(true);
          when(() => wallet.masterFingerprint).thenReturn(
            storage.entries.keys
                .singleWhere((key) => key.startsWith('seed_'))
                .substring(5),
          );
          when(
            () => walletRepository.getWallets(),
          ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([wallet]));
          throw Exception('wallet creation failed after storing its reference');
        });

        final result = await usecase.execute(mnemonicWords: words);

        expect((result as Err).failure, isA<ImportMnemonicUnexpectedFailure>());
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          hasLength(1),
        );
      },
    );

    test(
      'cleanup retains the new secret when wallet references cannot be read',
      () async {
        stubCreateWallet(() async => throw Exception('wallet creation failed'));
        when(
          () => walletRepository.getWallets(),
        ).thenThrow(Exception('wallet lookup failed'));

        final result = await usecase.execute(mnemonicWords: words);

        expect((result as Err).failure, isA<ImportMnemonicUnexpectedFailure>());
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          hasLength(1),
        );
      },
    );
  });
}
