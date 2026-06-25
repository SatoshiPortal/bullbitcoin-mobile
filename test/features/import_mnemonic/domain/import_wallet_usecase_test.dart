import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
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

class MockCheckDuplicateMnemonicUsecase extends Mock
    implements CheckDuplicateMnemonicUsecase {}

class MockSeedRepository extends Mock implements SeedRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockWalletRepository extends Mock implements WalletRepository {}

class MockWallet extends Mock implements Wallet {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      MnemonicSeed(
        mnemonicWords: const [],
        bytes: Uint8List(0),
        masterFingerprint: '',
      ),
    );
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(ScriptType.bip84);
  });

  late MockCheckDuplicateMnemonicUsecase checkDuplicate;
  late MockSeedRepository seedRepository;
  late MockSettingsRepository settingsRepository;
  late MockWalletRepository walletRepository;
  late ImportWalletUsecase usecase;

  const words = ['abandon', 'abandon', 'abandon', 'abandon', 'abandon',
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about'];

  final fakeSeed = MnemonicSeed(
    mnemonicWords: words,
    bytes: Uint8List(32),
    masterFingerprint: 'aabbccdd',
  );

  final fakeSettings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
  );

  setUp(() {
    checkDuplicate = MockCheckDuplicateMnemonicUsecase();
    seedRepository = MockSeedRepository();
    settingsRepository = MockSettingsRepository();
    walletRepository = MockWalletRepository();
    usecase = ImportWalletUsecase(
      checkDuplicateMnemonicUsecase: checkDuplicate,
      seedRepository: seedRepository,
      settingsRepository: settingsRepository,
      walletRepository: walletRepository,
    );
  });

  group('ImportWalletUsecase', () {
    test('returns Ok(wallet) on success', () async {
      final fakeWallet = MockWallet();
      when(() => checkDuplicate.execute(
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      )).thenAnswer((_) async => const Ok(null));
      when(() => settingsRepository.fetch())
          .thenAnswer((_) async => fakeSettings);
      when(() => seedRepository.createFromMnemonic(
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      )).thenAnswer((_) async => fakeSeed);
      when(() => walletRepository.createWallet(
        seed: any(named: 'seed'),
        network: any(named: 'network'),
        scriptType: any(named: 'scriptType'),
        isDefault: any(named: 'isDefault'),
        sync: any(named: 'sync'),
        label: any(named: 'label'),
      )).thenAnswer((_) async => fakeWallet);

      final result = await usecase.execute(
        mnemonicWords: words,
        label: 'My Wallet',
      );

      expect(result, isA<Ok<Wallet, ImportMnemonicFailure>>());
      expect((result as Ok).value, fakeWallet);
    });

    test(
      'returns Err(ImportMnemonicDuplicateFailure) when duplicate — no raw leak',
      () async {
        when(() => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        )).thenAnswer(
          (_) async => const Err(ImportMnemonicDuplicateFailure()),
        );

        final result = await usecase.execute(
          mnemonicWords: words,
          label: 'My Wallet',
        );

        expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
        expect(
          (result as Err).failure,
          isA<ImportMnemonicDuplicateFailure>(),
        );
        verifyNever(() => settingsRepository.fetch());
      },
    );

    test(
      'returns Err(ImportMnemonicUnexpectedFailure) on exception — raw message in logMessage only',
      () async {
        when(() => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        )).thenAnswer((_) async => const Ok(null));
        when(() => settingsRepository.fetch())
            .thenThrow(Exception('settings unavailable'));

        final result = await usecase.execute(
          mnemonicWords: words,
          label: 'My Wallet',
        );

        expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<ImportMnemonicUnexpectedFailure>());
        expect(
          (failure as ImportMnemonicUnexpectedFailure).logMessage,
          contains('settings unavailable'),
        );
      },
    );
  });
}
