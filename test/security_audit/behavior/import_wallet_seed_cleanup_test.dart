import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
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

/// An import must delete only what it created.
///
/// Deleting a secret an earlier import stored would destroy a wallet the user still has; leaving one this import created would litter the keystore with an orphan. The three failure points below are the ones that tell the two apart.
///
/// Now asserted against the real `Secrets` and an in-memory keystore: the question is whether the entry is still there, not whether a mock method was called.
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
  const settings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );

  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late _MockCheckDuplicateMnemonicUsecase checkDuplicate;
  late _MockSettingsRepository settingsRepository;
  late _MockWalletRepository walletRepository;
  late ImportWalletUsecase usecase;

  Iterable<String> storedSecrets() =>
      storage.entries.keys.where((k) => k.startsWith('seed_'));

  setUpAll(() async {
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
    // No wallet references any seed unless a test says so.
    when(() => walletRepository.getWallets()).thenAnswer((_) async => []);
  });

  void failCreateWalletWith(Object error) {
    when(
      () => walletRepository.createWallet(
        secret: any(named: 'secret'),
        network: any(named: 'network'),
        scriptType: any(named: 'scriptType'),
        isDefault: any(named: 'isDefault'),
        sync: any(named: 'sync'),
        label: any(named: 'label'),
      ),
    ).thenThrow(error);
  }

  group('ImportWalletUsecase serialises concurrent imports', () {
    test('a second execute never runs while the first is in flight', () async {
      // The usecase guards its body with a process-wide Lock. Nothing
      // asserted it, so the lock could be deleted and the whole suite
      // stayed green — the cleanup tests above reproduce the race's
      // OUTCOME by stubbing the wallet list, not the race itself.
      //
      // Probed from inside the locked body: settings.fetch() is the first
      // await _execute performs, so counting overlapping calls to it
      // counts overlapping bodies.
      var inFlight = 0;
      var peak = 0;
      when(() => settingsRepository.fetch()).thenAnswer((_) async {
        inFlight++;
        peak = peak > inFlight ? peak : inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        inFlight--;
        return settings;
      });
      failCreateWalletWith(
        const WalletAlreadyExistsException('existing-wallet-id'),
      );

      await Future.wait([
        usecase.execute(mnemonicWords: words),
        usecase.execute(mnemonicWords: words),
      ]);

      expect(
        peak,
        1,
        reason: 'two import bodies overlapped: the lock is not holding',
      );
    });
  });

  group('ImportWalletUsecase orphaned-secret cleanup', () {
    test(
      'keeps a stored secret when the failure precedes the import',
      () async {
        await secrets.import(words: words);
        when(
          () => settingsRepository.fetch(),
        ).thenThrow(Exception('settings unavailable'));

        final result = await usecase.execute(mnemonicWords: words);

        expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
        expect(storedSecrets(), hasLength(1));
      },
    );

    test('keeps a secret already referenced by an existing wallet', () async {
      await secrets.import(words: words);
      when(() => settingsRepository.fetch()).thenAnswer((_) async => settings);
      failCreateWalletWith(
        const WalletAlreadyExistsException('existing-wallet-id'),
      );

      final result = await usecase.execute(mnemonicWords: words);

      expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
      expect(
        storedSecrets(),
        hasLength(1),
        reason: 'this import did not create it, so it is not its to delete',
      );
    });

    test(
      'keeps a secret a wallet came to reference during this import',
      () async {
        // The race Codex reproduced (2026-09-16): another import of the same
        // words finished first and built its wallet on this seed. This
        // import created the entry, but it is not an orphan any more.
        when(
          () => settingsRepository.fetch(),
        ).thenAnswer((_) async => settings);
        when(() => walletRepository.getWallets()).thenAnswer(
          (_) async => [
            Wallet(
              origin: 'other-import',
              label: 'Other',
              network: Network.bitcoinMainnet,
              isDefault: false,
              masterFingerprint: '73c5da0a',
              xpubFingerprint: '73c5da0a',
              scriptType: ScriptType.bip84,
              xpub: 'xpub',
              externalPublicDescriptor: 'desc',
              internalPublicDescriptor: 'desc',
              signer: SignerEntity.local,
              signerDevice: null,
              balanceSat: BigInt.zero,
            ),
          ],
        );
        failCreateWalletWith(Exception('electrum unreachable'));

        final result = await usecase.execute(mnemonicWords: words);

        expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
        expect(
          storedSecrets(),
          hasLength(1),
          reason: 'the other wallet would be stranded without it',
        );
      },
    );

    test('still removes a secret this import actually orphaned', () async {
      when(() => settingsRepository.fetch()).thenAnswer((_) async => settings);
      failCreateWalletWith(Exception('electrum unreachable'));

      final result = await usecase.execute(mnemonicWords: words);

      expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
      expect(storedSecrets(), isEmpty);
    });
  });
}
