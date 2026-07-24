import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_genesis_block.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_birthday_checkpoint_failure.dart';
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

class MockCheckCompactBlockFiltersAvailableUsecase extends Mock
    implements CheckCompactBlockFiltersAvailableUsecase {}

class MockResolveWalletBirthdayCheckpointUsecase extends Mock
    implements ResolveWalletBirthdayCheckpointUsecase {}

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
    registerFallbackValue(BitcoinSyncBackend.electrum);
    registerFallbackValue(WalletBirthdayLookupMode.recovery);
  });

  final fakeCheckpoint = WalletBirthdayCheckpoint(
    requestedBirthday: DateTime.utc(2026),
    blockTimestamp: DateTime.utc(2026),
    blockHeight: 900000,
    blockHash: 'a' * 64,
  );

  late MockCheckDuplicateMnemonicUsecase checkDuplicate;
  late MockSeedRepository seedRepository;
  late MockSettingsRepository settingsRepository;
  late MockWalletRepository walletRepository;
  late MockCheckCompactBlockFiltersAvailableUsecase
  checkCompactBlockFiltersAvailable;
  late MockResolveWalletBirthdayCheckpointUsecase
  resolveWalletBirthdayCheckpoint;
  late ImportWalletUsecase usecase;

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

  final fakeSeed = MnemonicSeed(
    mnemonicWords: words,
    bytes: Uint8List(32),
    masterFingerprint: 'aabbccdd',
  );

  SettingsEntity buildSettings({bool useCompactBlockFiltersByDefault = false}) {
    return SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
      useCompactBlockFiltersByDefault: useCompactBlockFiltersByDefault,
    );
  }

  final fakeSettings = buildSettings();

  setUp(() {
    checkDuplicate = MockCheckDuplicateMnemonicUsecase();
    seedRepository = MockSeedRepository();
    settingsRepository = MockSettingsRepository();
    walletRepository = MockWalletRepository();
    checkCompactBlockFiltersAvailable =
        MockCheckCompactBlockFiltersAvailableUsecase();
    resolveWalletBirthdayCheckpoint =
        MockResolveWalletBirthdayCheckpointUsecase();
    usecase = ImportWalletUsecase(
      checkDuplicateMnemonicUsecase: checkDuplicate,
      seedRepository: seedRepository,
      settingsRepository: settingsRepository,
      walletRepository: walletRepository,
      checkCompactBlockFiltersAvailableUsecase:
          checkCompactBlockFiltersAvailable,
      resolveWalletBirthdayCheckpointUsecase: resolveWalletBirthdayCheckpoint,
    );
    when(
      () => resolveWalletBirthdayCheckpoint.execute(
        requestedBirthday: any(named: 'requestedBirthday'),
        isTestnet: any(named: 'isTestnet'),
        lookupMode: any(named: 'lookupMode'),
      ),
    ).thenAnswer((_) async => Ok(fakeCheckpoint));
  });

  group('ImportWalletUsecase', () {
    test('returns Ok(wallet) on success', () async {
      final fakeWallet = MockWallet();
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => fakeSettings);
      when(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => fakeSeed);
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      ).thenAnswer((_) async => fakeWallet);

      final result = await usecase.execute(
        mnemonicWords: words,
        label: 'My Wallet',
      );

      expect(result, isA<Ok<Wallet, ImportMnemonicFailure>>());
      expect((result as Ok).value, fakeWallet);
    });

    test('requests compactBlockFilters when the preference is on and CBF is '
        'available', () async {
      final fakeWallet = MockWallet();
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);
      when(
        () => resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: any(named: 'requestedBirthday'),
          isTestnet: any(named: 'isTestnet'),
          lookupMode: any(named: 'lookupMode'),
        ),
      ).thenAnswer((_) async => Ok(fakeCheckpoint));
      when(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => fakeSeed);
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
          birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
        ),
      ).thenAnswer((_) async => fakeWallet);

      final result = await usecase.execute(
        mnemonicWords: words,
        label: 'My Wallet',
      );

      expect(result, isA<Ok<Wallet, ImportMnemonicFailure>>());
      verify(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          birthdayCheckpoint: fakeCheckpoint,
        ),
      ).called(1);
    });

    test('falls back to electrum when CBF is unavailable (developer mode off, '
        'a production build without ENABLE_CBF, or Tor enabled), even with '
        'the preference on', () async {
      final fakeWallet = MockWallet();
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => false);
      when(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => fakeSeed);
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      ).thenAnswer((_) async => fakeWallet);

      final result = await usecase.execute(
        mnemonicWords: words,
        label: 'My Wallet',
      );

      expect(result, isA<Ok<Wallet, ImportMnemonicFailure>>());
      verify(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
          bitcoinSyncBackend: BitcoinSyncBackend.electrum,
        ),
      ).called(1);
    });

    test('falls back to electrum when the preference is off — the '
        'availability usecase is never even consulted', () async {
      final fakeWallet = MockWallet();
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => buildSettings(useCompactBlockFiltersByDefault: false),
      );
      when(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => fakeSeed);
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      ).thenAnswer((_) async => fakeWallet);

      final result = await usecase.execute(
        mnemonicWords: words,
        label: 'My Wallet',
      );

      expect(result, isA<Ok<Wallet, ImportMnemonicFailure>>());
      verify(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
          bitcoinSyncBackend: BitcoinSyncBackend.electrum,
        ),
      ).called(1);
      verifyNever(() => checkCompactBlockFiltersAvailable.execute());
    });

    test(
      'an explicit requestedSyncBackend overrides the global preference',
      () async {
        final fakeWallet = MockWallet();
        when(
          () => checkDuplicate.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: any(named: 'passphrase'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => settingsRepository.fetch(),
        ).thenAnswer((_) async => fakeSettings);
        when(
          () => checkCompactBlockFiltersAvailable.execute(),
        ).thenAnswer((_) async => true);
        when(
          () => seedRepository.createFromMnemonic(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: any(named: 'passphrase'),
          ),
        ).thenAnswer((_) async => fakeSeed);
        when(
          () => walletRepository.createWallet(
            seed: any(named: 'seed'),
            network: any(named: 'network'),
            scriptType: any(named: 'scriptType'),
            isDefault: any(named: 'isDefault'),
            sync: any(named: 'sync'),
            label: any(named: 'label'),
            bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
            birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
          ),
        ).thenAnswer((_) async => fakeWallet);

        final result = await usecase.execute(
          mnemonicWords: words,
          label: 'My Wallet',
          requestedSyncBackend: BitcoinSyncBackend.compactBlockFilters,
        );

        expect(result, isA<Ok<Wallet, ImportMnemonicFailure>>());
        verify(
          () => walletRepository.createWallet(
            seed: any(named: 'seed'),
            network: any(named: 'network'),
            scriptType: any(named: 'scriptType'),
            isDefault: any(named: 'isDefault'),
            sync: any(named: 'sync'),
            label: any(named: 'label'),
            bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
            birthdayCheckpoint: fakeCheckpoint,
          ),
        ).called(1);
      },
    );

    test('defaults to the network genesis birthday, in recovery mode, when no '
        'birthday is given', () async {
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => fakeSettings);
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);
      when(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => fakeSeed);
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
          birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
        ),
      ).thenAnswer((_) async => MockWallet());

      final result = await usecase.execute(
        mnemonicWords: words,
        label: 'My Wallet',
        requestedSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      );

      expect(result, isA<Ok<Wallet, ImportMnemonicFailure>>());
      verify(
        () => resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: BitcoinGenesisBlock.mainnet.timestamp,
          isTestnet: false,
          lookupMode: WalletBirthdayLookupMode.recovery,
        ),
      ).called(1);
    });

    test(
      'forwards a custom birthday to the resolver in recovery mode',
      () async {
        when(
          () => checkDuplicate.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: any(named: 'passphrase'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => settingsRepository.fetch(),
        ).thenAnswer((_) async => fakeSettings);
        when(
          () => checkCompactBlockFiltersAvailable.execute(),
        ).thenAnswer((_) async => true);
        when(
          () => seedRepository.createFromMnemonic(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: any(named: 'passphrase'),
          ),
        ).thenAnswer((_) async => fakeSeed);
        when(
          () => walletRepository.createWallet(
            seed: any(named: 'seed'),
            network: any(named: 'network'),
            scriptType: any(named: 'scriptType'),
            isDefault: any(named: 'isDefault'),
            sync: any(named: 'sync'),
            label: any(named: 'label'),
            bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
            birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
          ),
        ).thenAnswer((_) async => MockWallet());
        final requestedBirthday = DateTime.utc(2022, 6, 1);

        final result = await usecase.execute(
          mnemonicWords: words,
          label: 'My Wallet',
          requestedSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          birthday: requestedBirthday,
        );

        expect(result, isA<Ok<Wallet, ImportMnemonicFailure>>());
        verify(
          () => resolveWalletBirthdayCheckpoint.execute(
            requestedBirthday: requestedBirthday,
            isTestnet: false,
            lookupMode: WalletBirthdayLookupMode.recovery,
          ),
        ).called(1);
      },
    );

    test('returns Err(ImportMnemonicBirthdayCheckpointFailure) when the '
        'resolver fails, without creating the wallet', () async {
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => fakeSettings);
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);
      when(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => fakeSeed);
      when(
        () => resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: any(named: 'requestedBirthday'),
          isTestnet: any(named: 'isTestnet'),
          lookupMode: any(named: 'lookupMode'),
        ),
      ).thenAnswer(
        (_) async => const Err(WalletBirthdayCheckpointLookupFailure('boom')),
      );

      final result = await usecase.execute(
        mnemonicWords: words,
        label: 'My Wallet',
        requestedSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      );

      expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
      expect(
        (result as Err<Wallet, ImportMnemonicFailure>).failure,
        isA<ImportMnemonicBirthdayCheckpointFailure>(),
      );
      verifyNever(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          sync: any(named: 'sync'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      );
    });

    test(
      'returns Err(ImportMnemonicDuplicateFailure) when duplicate — no raw leak',
      () async {
        when(
          () => checkDuplicate.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: any(named: 'passphrase'),
          ),
        ).thenAnswer((_) async => const Err(ImportMnemonicDuplicateFailure()));

        final result = await usecase.execute(
          mnemonicWords: words,
          label: 'My Wallet',
        );

        expect(result, isA<Err<Wallet, ImportMnemonicFailure>>());
        expect((result as Err).failure, isA<ImportMnemonicDuplicateFailure>());
        verifyNever(() => settingsRepository.fetch());
      },
    );

    test(
      'returns Err(ImportMnemonicUnexpectedFailure) on exception — raw message in logMessage only',
      () async {
        when(
          () => checkDuplicate.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: any(named: 'passphrase'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => settingsRepository.fetch(),
        ).thenThrow(Exception('settings unavailable'));

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
