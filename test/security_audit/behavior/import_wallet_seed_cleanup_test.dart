// Behavioral proof for the audit finding on ImportWalletUsecase's
// orphaned-seed cleanup (issue #2634 fix).
//
// The cleanup added in `fix(import)` runs from a catch block that also covers
// failures raised BEFORE this import created a seed. The fingerprint is
// recomputed from the mnemonic, so the deletion targets whatever seed is
// stored for that mnemonic — including one an already-imported wallet
// depends on.
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
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

class _MockCheckDuplicateMnemonicUsecase extends Mock
    implements CheckDuplicateMnemonicUsecase {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

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
  const fingerprint = 'aabbccdd';

  final seed = MnemonicSeed(
    mnemonicWords: words,
    bytes: Uint8List(32),
    masterFingerprint: fingerprint,
  );

  final settings = const SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );

  late _MockCheckDuplicateMnemonicUsecase checkDuplicate;
  late _MockSeedRepository seedRepository;
  late _MockSettingsRepository settingsRepository;
  late _MockWalletRepository walletRepository;
  late ImportWalletUsecase usecase;

  setUpAll(() {
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(ScriptType.bip84);
    registerFallbackValue(seed);
  });

  setUp(() {
    checkDuplicate = _MockCheckDuplicateMnemonicUsecase();
    seedRepository = _MockSeedRepository();
    settingsRepository = _MockSettingsRepository();
    walletRepository = _MockWalletRepository();

    usecase = ImportWalletUsecase(
      checkDuplicateMnemonicUsecase: checkDuplicate,
      seedRepository: seedRepository,
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
      () => seedRepository.fingerprintFor(
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenReturn(fingerprint);
    when(
      () => seedRepository.delete(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => seedRepository.exists(any())).thenAnswer((_) async => true);
  });

  group('ImportWalletUsecase orphaned-seed cleanup', () {
    test(
      'keeps the stored seed when the failure precedes seed creation',
      () async {
        // Nothing was persisted by this import: the settings read blew up first.
        when(
          () => settingsRepository.fetch(),
        ).thenThrow(Exception('settings unavailable'));

        final result = await usecase.execute(mnemonicWords: words);

        expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
        verifyNever(
          () => seedRepository.createFromMnemonic(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: any(named: 'passphrase'),
          ),
        );
        verifyNever(() => seedRepository.delete(any()));
      },
    );

    test('keeps a seed already referenced by an existing wallet', () async {
      when(() => settingsRepository.fetch()).thenAnswer((_) async => settings);
      when(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => seed);
      // The wallet derived from this mnemonic is already in the database, so
      // its seed must survive the failed re-import.
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
        ),
      ).thenThrow(const WalletAlreadyExistsException('existing-wallet-id'));

      final result = await usecase.execute(mnemonicWords: words);

      expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
      verifyNever(() => seedRepository.delete(any()));
    });

    test('still removes a seed this import actually orphaned', () async {
      when(() => settingsRepository.fetch()).thenAnswer((_) async => settings);
      when(() => seedRepository.exists(any())).thenAnswer((_) async => false);
      when(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => seed);
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
        ),
      ).thenThrow(Exception('electrum unreachable'));

      final result = await usecase.execute(mnemonicWords: words);

      expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
      verify(() => seedRepository.delete(fingerprint)).called(1);
    });
  });
}
