import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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

class _MockWallet extends Mock implements Wallet {}

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
      'a secret this import created is removed when the wallet cannot be built (#2634)',
      () async {
        stubCreateWallet(() async => throw Exception('wallet creation failed'));

        final result = await usecase.execute(mnemonicWords: words);

        expect((result as Err).failure, isA<ImportMnemonicUnexpectedFailure>());
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          isEmpty,
          reason: 'the import that created it owns the cleanup',
        );
      },
    );

    test('a secret that was already stored survives a failed import', () async {
      // Imported before this run: the failing import did not create it, so it is not its to delete.
      await secrets.import(words: words);
      stubCreateWallet(() async => throw Exception('wallet creation failed'));

      final result = await usecase.execute(mnemonicWords: words);

      expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
      expect(
        storage.entries.keys.where((k) => k.startsWith('seed_')),
        hasLength(1),
      );
    });
  });
}
