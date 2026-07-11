import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

SettingsEntity _settings({
  bool? isSuperuser = true,
  bool? isDevModeEnabled = true,
}) => const SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
  isSuperuser: null,
).copyWith(isSuperuser: isSuperuser, isDevModeEnabled: isDevModeEnabled);

Seed _mnemonicSeed() => Seed.mnemonic(
  mnemonicWords: 'abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon about'
      .split(' '),
  bytes: Uint8List.fromList(List<int>.filled(64, 1)),
  masterFingerprint: '00000000',
);

Seed _bytesSeed() => Seed.bytes(
  bytes: Uint8List.fromList(List<int>.filled(32, 2)),
  masterFingerprint: '11111111',
);

void main() {
  late _MockGetDefaultSeedUsecase seedUsecase;
  late _MockSettingsRepository settingsRepo;
  late FakeSpAccountRepository accountRepo;
  late FakeSpBackendConfigRepository configRepo;
  late CreateSpWalletUsecase usecase;

  CreateSpWalletUsecase build() => CreateSpWalletUsecase(
    getDefaultSeedUsecase: seedUsecase,
    settingsRepository: settingsRepo,
    repository: accountRepo,
    configRepository: configRepo,
  );

  Future<Result<void, SpFailure>> run() => usecase.execute(
    network: SpNetwork.regtest,
    blindbitUrl: 'http://blindbit.example',
    electrumUrl: 'tcp://electrum.example:50001',
  );

  setUp(() {
    seedUsecase = _MockGetDefaultSeedUsecase();
    settingsRepo = _MockSettingsRepository();
    // hasSessionValue false so create actually reaches createFromMnemonic.
    accountRepo = FakeSpAccountRepository(hasSessionValue: false);
    configRepo = FakeSpBackendConfigRepository();

    when(() => settingsRepo.fetch()).thenAnswer((_) async => _settings());
    when(() => seedUsecase.execute()).thenAnswer((_) async => _mnemonicSeed());
    usecase = build();
  });

  group('CreateSpWalletUsecase gates', () {
    test('refuses with SpRequiresSuperuser when superuser is off', () async {
      when(
        () => settingsRepo.fetch(),
      ).thenAnswer((_) async => _settings(isSuperuser: false));

      final result = await run();

      expect(result, isA<Err<void, SpFailure>>());
      expect((result as Err).failure, isA<SpRequiresSuperuser>());
      expect(accountRepo.createCount, 0, reason: 'no create on a gated setup');
    });

    test('refuses with SpRequiresDevMode when dev mode is off', () async {
      when(
        () => settingsRepo.fetch(),
      ).thenAnswer((_) async => _settings(isDevModeEnabled: false));

      final result = await run();

      expect((result as Err).failure, isA<SpRequiresDevMode>());
      expect(accountRepo.createCount, 0);
    });

    test('checks superuser before dev mode', () async {
      when(() => settingsRepo.fetch()).thenAnswer(
        (_) async => _settings(isSuperuser: false, isDevModeEnabled: false),
      );

      final result = await run();

      expect(
        (result as Err).failure,
        isA<SpRequiresSuperuser>(),
        reason: 'the superuser gate is evaluated first',
      );
    });
  });

  group('CreateSpWalletUsecase double-setup', () {
    test('refuses with SpAlreadySetUp when a config is stored and no sentinel',
        () async {
      await configRepo.save(
        SpBackendConfig(
          network: SpNetwork.regtest,
          blindbitUrl: 'http://existing.example',
          electrumUrl: 'tcp://existing.example:50001',
        ),
      );

      final result = await run();

      expect((result as Err).failure, isA<SpAlreadySetUp>());
      expect(accountRepo.createCount, 0, reason: 'never recreate over a wallet');
    });

    test('a corrupt stored config does not block setup (counts as absent)',
        () async {
      configRepo.failFetch = true;

      final result = await run();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(accountRepo.createCount, 1);
    });
  });

  group('CreateSpWalletUsecase stale-sentinel cleanup', () {
    test('wipes the stale account dir, then creates and persists the config',
        () async {
      accountRepo.sentinel = true; // a prior revoke left a sentinel behind

      final result = await run();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(accountRepo.sentinel, isFalse, reason: 'stale dir was wiped');
      expect(accountRepo.createCount, 1);
      expect(
        (await configRepo.fetch()),
        isA<Ok<SpBackendConfig?, SpFailure>>()
            .having((r) => (r as Ok).value, 'config', isNotNull),
      );
    });

    test('refuses with SpSetupCleanupFailed when the stale wipe throws',
        () async {
      accountRepo.sentinel = true;
      accountRepo.wipeShouldThrow = true;

      final result = await run();

      expect((result as Err).failure, isA<SpSetupCleanupFailed>());
      expect(accountRepo.createCount, 0, reason: 'no create if cleanup failed');
    });
  });

  group('CreateSpWalletUsecase seed + create failures', () {
    test('a non-mnemonic seed throws StateError (programmer-bug path)',
        () async {
      when(() => seedUsecase.execute()).thenAnswer((_) async => _bytesSeed());

      await expectLater(run(), throwsA(isA<StateError>()));
      expect(accountRepo.createCount, 0);
    });

    test('maps a createFromMnemonic throw to SpUnexpected', () async {
      accountRepo.createShouldThrow = true;

      final result = await run();

      expect((result as Err).failure, isA<SpUnexpected>());
    });

    test('rolls the config back on a createFromMnemonic throw so retry is not '
        'wedged by SpAlreadySetUp', () async {
      accountRepo.createShouldThrow = true;

      final result = await run();

      expect((result as Err).failure, isA<SpUnexpected>());
      final stored =
          (await configRepo.fetch()) as Ok<SpBackendConfig?, SpFailure>;
      expect(
        stored.value,
        isNull,
        reason: 'a failed first-time setup must leave no persisted config, '
            'else the next setup hits the double-setup guard',
      );
    });

    test('a save throw returns Err (execute is total, does not throw)',
        () async {
      configRepo.saveShouldThrow = true;

      final result = await run();

      expect((result as Err).failure, isA<SpUnexpected>());
      expect(accountRepo.createCount, 0, reason: 'save is before create');
    });

    test('a seed read throw returns Err (execute is total, does not throw)',
        () async {
      when(
        () => seedUsecase.execute(),
      ).thenThrow(Exception('seed read failed'));

      final result = await run();

      expect((result as Err).failure, isA<SpUnexpected>());
      expect(accountRepo.createCount, 0);
    });

    test('happy path returns Ok and persists the checked config', () async {
      final result = await run();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(accountRepo.createCount, 1);
      final stored = (await configRepo.fetch()) as Ok<SpBackendConfig?, SpFailure>;
      expect(stored.value?.network, SpNetwork.regtest);
      expect(stored.value?.blindbitUrl, 'http://blindbit.example');
    });
  });
}
