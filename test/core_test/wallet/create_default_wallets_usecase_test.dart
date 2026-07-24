import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_birthday_checkpoint_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockMnemonicGenerator extends Mock implements MnemonicGenerator {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockCheckCompactBlockFiltersAvailableUsecase extends Mock
    implements CheckCompactBlockFiltersAvailableUsecase {}

class _MockResolveWalletBirthdayCheckpointUsecase extends Mock
    implements ResolveWalletBirthdayCheckpointUsecase {}

class _MockWallet extends Mock implements Wallet {}

const _words = [
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

SettingsEntity _buildSettings({bool useCompactBlockFiltersByDefault = false}) {
  return SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    useCompactBlockFiltersByDefault: useCompactBlockFiltersByDefault,
  );
}

void main() {
  late _MockSeedRepository seedRepository;
  late _MockMnemonicGenerator mnemonicGenerator;
  late _MockSettingsRepository settingsRepository;
  late _MockWalletRepository walletRepository;
  late _MockCheckCompactBlockFiltersAvailableUsecase
  checkCompactBlockFiltersAvailable;
  late _MockResolveWalletBirthdayCheckpointUsecase
  resolveWalletBirthdayCheckpoint;
  late CreateDefaultWalletsUsecase usecase;

  final fakeSeed = MnemonicSeed(
    mnemonicWords: _words,
    bytes: Uint8List(32),
    masterFingerprint: 'aabbccdd',
  );

  final fakeCheckpoint = WalletBirthdayCheckpoint(
    requestedBirthday: DateTime.utc(2026),
    blockTimestamp: DateTime.utc(2026),
    blockHeight: 900000,
    blockHash: 'a' * 64,
  );

  setUpAll(() {
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(ScriptType.bip84);
    registerFallbackValue(BitcoinSyncBackend.electrum);
    registerFallbackValue(fakeSeed);
    registerFallbackValue(WalletBirthdayLookupMode.newWallet);
  });

  setUp(() {
    seedRepository = _MockSeedRepository();
    mnemonicGenerator = _MockMnemonicGenerator();
    settingsRepository = _MockSettingsRepository();
    walletRepository = _MockWalletRepository();
    checkCompactBlockFiltersAvailable =
        _MockCheckCompactBlockFiltersAvailableUsecase();
    resolveWalletBirthdayCheckpoint =
        _MockResolveWalletBirthdayCheckpointUsecase();
    usecase = CreateDefaultWalletsUsecase(
      seedRepository: seedRepository,
      settingsRepository: settingsRepository,
      mnemonicGenerator: mnemonicGenerator,
      walletRepository: walletRepository,
      checkCompactBlockFiltersAvailableUsecase:
          checkCompactBlockFiltersAvailable,
      resolveWalletBirthdayCheckpointUsecase: resolveWalletBirthdayCheckpoint,
    );

    when(
      () => walletRepository.getWallets(
        onlyDefaults: any(named: 'onlyDefaults'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => []);
    when(() => mnemonicGenerator.generate()).thenReturn(_words);
    when(
      () => seedRepository.createFromMnemonic(
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) async => fakeSeed);
    // Two stubs are needed: `CreateDefaultWalletsUsecase` always passes
    // `birthdayCheckpoint:` explicitly for the Bitcoin wallet (even when
    // null) but never for Liquid, which has no CBF datasource — and
    // mocktail matches a stub/verify only against calls whose named
    // argument *keys* match exactly (see `InvocationMatcher`), so a single
    // stub covering both shapes is not possible.
    when(
      () => walletRepository.createWallet(
        seed: any(named: 'seed'),
        network: any(named: 'network'),
        scriptType: any(named: 'scriptType'),
        isDefault: any(named: 'isDefault'),
        birthday: any(named: 'birthday'),
        bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
      ),
    ).thenAnswer((_) async => _MockWallet());
    when(
      () => walletRepository.createWallet(
        seed: any(named: 'seed'),
        network: any(named: 'network'),
        scriptType: any(named: 'scriptType'),
        isDefault: any(named: 'isDefault'),
        birthday: any(named: 'birthday'),
        bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
      ),
    ).thenAnswer((_) async => _MockWallet());
  });

  test('a freshly generated wallet with the preference on and CBF available '
      'requests compactBlockFilters for the Bitcoin wallet only', () async {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
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

    await usecase.execute();

    verify(
      () => walletRepository.createWallet(
        seed: any(named: 'seed'),
        network: Network.bitcoinMainnet,
        scriptType: any(named: 'scriptType'),
        isDefault: true,
        birthday: any(named: 'birthday'),
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
        birthdayCheckpoint: fakeCheckpoint,
      ),
    ).called(1);
    verify(
      () => walletRepository.createWallet(
        seed: any(named: 'seed'),
        network: Network.liquidMainnet,
        scriptType: any(named: 'scriptType'),
        isDefault: true,
        birthday: any(named: 'birthday'),
        bitcoinSyncBackend: BitcoinSyncBackend.electrum,
      ),
    ).called(1);
  });

  test('a freshly generated wallet with CBF active resolves the checkpoint for '
      'the current chain tip — the same instant used as the wallet birthday, '
      'not a recovery-style requested date', () async {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
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

    final before = DateTime.now().toUtc();
    await usecase.execute();
    final after = DateTime.now().toUtc();

    final captured = verify(
      () => resolveWalletBirthdayCheckpoint.execute(
        requestedBirthday: captureAny(named: 'requestedBirthday'),
        isTestnet: any(named: 'isTestnet'),
        lookupMode: any(named: 'lookupMode'),
      ),
    ).captured;
    expect(captured, hasLength(1));
    final requestedBirthday = captured.single as DateTime;
    expect(
      requestedBirthday.isAfter(before) ||
          requestedBirthday.isAtSameMomentAs(before),
      isTrue,
    );
    expect(
      requestedBirthday.isBefore(after) ||
          requestedBirthday.isAtSameMomentAs(after),
      isTrue,
    );
  });

  test(
    'a checkpoint resolution failure aborts wallet creation entirely — no '
    'Bitcoin or Liquid wallet is created, so nothing needs to be rolled back',
    () async {
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
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
      ).thenAnswer(
        (_) async => const Err(
          WalletBirthdayCheckpointLookupFailure('no_reachable_source'),
        ),
      );

      await expectLater(
        usecase.execute(),
        throwsA(isA<CreateDefaultWalletsException>()),
      );

      verifyNever(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          birthday: any(named: 'birthday'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
          birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
        ),
      );
      verifyNever(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          birthday: any(named: 'birthday'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      );
      verifyNever(
        () => walletRepository.deleteWallet(walletId: any(named: 'walletId')),
      );
    },
  );

  test(
    'a wallet-creation failure after a resolved checkpoint rolls back the '
    'already-created Bitcoin wallet (and its BDK files, via deleteWallet)',
    () async {
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
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

      final createdBitcoinWallet = _MockWallet();
      when(() => createdBitcoinWallet.id).thenReturn('btc-wallet-id');
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: Network.bitcoinMainnet,
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          birthday: any(named: 'birthday'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
          birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
        ),
      ).thenAnswer((_) async => createdBitcoinWallet);
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: Network.liquidMainnet,
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          birthday: any(named: 'birthday'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      ).thenThrow(Exception('liquid wallet creation failed'));
      when(
        () => walletRepository.deleteWallet(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async {});

      await expectLater(
        usecase.execute(),
        throwsA(isA<CreateDefaultWalletsException>()),
      );

      verify(
        () => walletRepository.deleteWallet(walletId: 'btc-wallet-id'),
      ).called(1);
    },
  );

  test('the preference is ignored when CBF is unavailable (developer mode off '
      'or a production build without ENABLE_CBF)', () async {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
    );
    when(
      () => checkCompactBlockFiltersAvailable.execute(),
    ).thenAnswer((_) async => false);

    await usecase.execute();

    verify(
      () => walletRepository.createWallet(
        seed: any(named: 'seed'),
        network: Network.bitcoinMainnet,
        scriptType: any(named: 'scriptType'),
        isDefault: true,
        birthday: any(named: 'birthday'),
        bitcoinSyncBackend: BitcoinSyncBackend.electrum,
        birthdayCheckpoint: null,
      ),
    ).called(1);
    verifyNever(
      () => resolveWalletBirthdayCheckpoint.execute(
        requestedBirthday: any(named: 'requestedBirthday'),
        isTestnet: any(named: 'isTestnet'),
        lookupMode: any(named: 'lookupMode'),
      ),
    );
  });

  test('the preference is ignored when it is false — the availability usecase '
      'is never even consulted, thanks to short-circuit evaluation', () async {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => _buildSettings(useCompactBlockFiltersByDefault: false),
    );

    await usecase.execute();

    verify(
      () => walletRepository.createWallet(
        seed: any(named: 'seed'),
        network: Network.bitcoinMainnet,
        scriptType: any(named: 'scriptType'),
        isDefault: true,
        birthday: any(named: 'birthday'),
        bitcoinSyncBackend: BitcoinSyncBackend.electrum,
        birthdayCheckpoint: null,
      ),
    ).called(1);
    verifyNever(() => checkCompactBlockFiltersAvailable.execute());
    verifyNever(
      () => resolveWalletBirthdayCheckpoint.execute(
        requestedBirthday: any(named: 'requestedBirthday'),
        isTestnet: any(named: 'isTestnet'),
        lookupMode: any(named: 'lookupMode'),
      ),
    );
  });

  test('a recovered wallet with an externally-resolved checkpoint honors the '
      'compactBlockFilters preference and persists that checkpoint — this '
      "use-case never resolves one itself for a recovery (mnemonicWords != "
      'null): the caller (bloc, after its own birthday-picker UI) must resolve '
      'with WalletBirthdayLookupMode.recovery and pass it in', () async {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
    );
    when(
      () => checkCompactBlockFiltersAvailable.execute(),
    ).thenAnswer((_) async => true);

    await usecase.execute(
      mnemonicWords: _words,
      bitcoinBirthdayCheckpoint: fakeCheckpoint,
    );

    verify(
      () => walletRepository.createWallet(
        seed: any(named: 'seed'),
        network: Network.bitcoinMainnet,
        scriptType: any(named: 'scriptType'),
        isDefault: true,
        birthday: fakeCheckpoint.requestedBirthday,
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
        birthdayCheckpoint: fakeCheckpoint,
      ),
    ).called(1);
    verifyNever(
      () => resolveWalletBirthdayCheckpoint.execute(
        requestedBirthday: any(named: 'requestedBirthday'),
        isTestnet: any(named: 'isTestnet'),
        lookupMode: any(named: 'lookupMode'),
      ),
    );
  });

  test(
    'a recovered wallet that opted into compactBlockFilters but has no '
    'externally-resolved checkpoint fails closed — no partial (Bitcoin-only '
    'or Liquid-only) wallet pair is ever created without one, since '
    "CbfScanTypeResolver can't safely scan a recovery without a checkpoint",
    () async {
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);

      await expectLater(
        usecase.execute(mnemonicWords: _words),
        throwsA(isA<CreateDefaultWalletsException>()),
      );

      verifyNever(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          birthday: any(named: 'birthday'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
          birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
        ),
      );
      verifyNever(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          birthday: any(named: 'birthday'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      );
    },
  );

  test(
    'a recovered wallet on Electrum (the preference off) ignores a passed-in '
    'checkpoint entirely — it is CBF-only',
    () async {
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: false),
      );

      await usecase.execute(
        mnemonicWords: _words,
        bitcoinBirthdayCheckpoint: fakeCheckpoint,
      );

      verify(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: Network.bitcoinMainnet,
          scriptType: any(named: 'scriptType'),
          isDefault: true,
          birthday: null,
          bitcoinSyncBackend: BitcoinSyncBackend.electrum,
          birthdayCheckpoint: null,
        ),
      ).called(1);
      verifyNever(() => checkCompactBlockFiltersAvailable.execute());
    },
  );

  test(
    'an already-existing default Bitcoin wallet is never touched — no '
    'createWallet call for Bitcoin at all, and no checkpoint is resolved',
    () async {
      final existingBitcoin = _MockWallet();
      when(() => existingBitcoin.network).thenReturn(Network.bitcoinMainnet);
      when(() => existingBitcoin.id).thenReturn('existing-bitcoin');
      when(
        () => walletRepository.getWallets(
          onlyDefaults: any(named: 'onlyDefaults'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => [existingBitcoin]);
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);

      await usecase.execute();

      verify(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: Network.liquidMainnet,
          scriptType: any(named: 'scriptType'),
          isDefault: true,
          birthday: any(named: 'birthday'),
          bitcoinSyncBackend: BitcoinSyncBackend.electrum,
        ),
      ).called(1);
      verifyNever(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: Network.bitcoinMainnet,
          scriptType: any(named: 'scriptType'),
          isDefault: any(named: 'isDefault'),
          birthday: any(named: 'birthday'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      );
      verifyNever(
        () => resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: any(named: 'requestedBirthday'),
          isTestnet: any(named: 'isTestnet'),
          lookupMode: any(named: 'lookupMode'),
        ),
      );
    },
  );
}
