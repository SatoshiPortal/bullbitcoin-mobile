import 'dart:async';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';

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

void main() {
  late MockGetSpSecretUsecase secretUsecase;
  late _MockSettingsRepository settingsRepo;
  late FakeSpAccountRepository accountRepo;
  late FakeSpBackendConfigRepository configRepo;
  late CreateSpWalletUsecase usecase;

  CreateSpWalletUsecase build({WalletMutationGuard? mutationGuard}) =>
      CreateSpWalletUsecase(
        walletMutationGuard: mutationGuard ?? WalletMutationGuard(),
        guard: SpSessionGuard(),
        getSpSecretUsecase: secretUsecase,
        settingsRepository: settingsRepo,
        repository: accountRepo,
        files: accountRepo,
        configRepository: configRepo,
        scanSpWalletUsecase: ScanSpWalletUsecase(repository: accountRepo),
      );

  Future<Result<void, SpFailure>> run({bool scanFromNow = false}) =>
      usecase.execute(
        network: BitcoinNetwork.regtest,
        walletId: 'wallet',
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
        scanFromNow: scanFromNow,
      );

  setUpAll(() => registerFallbackValue(BitcoinNetwork.regtest));

  setUp(() async {
    secretUsecase = MockGetSpSecretUsecase();
    final secret = await spSecret();
    settingsRepo = _MockSettingsRepository();
    // hasSessionValue false so create actually reaches createFromSecret.
    accountRepo = FakeSpAccountRepository(
      hasSessionValue: false,
      accountDir: false,
    );
    configRepo = FakeSpBackendConfigRepository();

    when(() => settingsRepo.fetch()).thenAnswer((_) async => _settings());
    when(
      () => secretUsecase.resolve(any(), walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => Ok((secret: secret, binding: spSourceBinding)));
    usecase = build();
  });

  test(
    'holds the shared mutation guard across source selection and config save',
    () async {
      final guard = WalletMutationGuard();
      final entered = Completer<void>();
      final resume = Completer<void>();
      final secret = await spSecret();
      when(
        () => secretUsecase.resolve(any(), walletId: any(named: 'walletId')),
      ).thenAnswer((_) async {
        entered.complete();
        await resume.future;
        return Ok((secret: secret, binding: spSourceBinding));
      });
      usecase = build(mutationGuard: guard);
      final creating = run();
      await entered.future;
      var mutationEntered = false;
      final otherMutation = guard.exclusive(() async {
        mutationEntered = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(mutationEntered, isFalse);
      resume.complete();
      expect(await creating, isA<Ok<void, SpFailure>>());
      await otherMutation;
      expect(mutationEntered, isTrue);
    },
  );

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
    test('does not overwrite orphaned backups without a config', () async {
      accountRepo.orphanBackups = true;
      final result = await run();
      expect((result as Err).failure, isA<SpRecoveryRequired>());
      expect(accountRepo.createCount, 0);
    });

    test('does not overwrite an account directory without a config', () async {
      accountRepo.accountDir = true;
      final result = await run();
      expect((result as Err).failure, isA<SpRecoveryRequired>());
      expect(accountRepo.createCount, 0);
    });

    test(
      'refuses with SpAlreadySetUp when a config is stored and no sentinel',
      () async {
        await configRepo.save(
          SpBackendConfig(
            network: BitcoinNetwork.regtest,
            blindbitUrl: 'http://existing.example',
            electrumUrl: 'tcp://existing.example:50001',
          ),
        );

        final result = await run();

        expect((result as Err).failure, isA<SpAlreadySetUp>());
        expect(
          accountRepo.createCount,
          0,
          reason: 'never recreate over a wallet',
        );
      },
    );

    test(
      'a failed config read refuses rather than creating over a wallet',
      () async {
        // Folding the read failure to "no config" would defeat the guard above
        // and let this create run over a live wallet, re-seeding its scan cursor.
        configRepo.readShouldFail = true;

        final result = await run();

        expect((result as Err).failure, isA<SpUnexpected>());
        expect(accountRepo.createCount, 0);
      },
    );

    test('a corrupt stored config blocks setup', () async {
      configRepo.failFetch = true;

      final result = await run();

      expect(result, isA<Err<void, SpFailure>>());
      expect(accountRepo.createCount, 0);
    });
  });

  group('CreateSpWalletUsecase incomplete revoke', () {
    test(
      'preserves the revoked directory and requires an explicit retry',
      () async {
        accountRepo.sentinel = true;
        accountRepo.accountDir = true;
        final result = await run();
        expect((result as Err).failure, isA<SpRecoveryRequired>());
        expect(accountRepo.sentinel, isTrue);
        expect(accountRepo.accountDir, isTrue);
        expect(accountRepo.createCount, 0);
      },
    );
  });

  group('CreateSpWalletUsecase secret + create failures', () {
    test('looks the secret up on the network being set up', () async {
      await run();

      verify(
        () => secretUsecase.resolve(BitcoinNetwork.regtest, walletId: 'wallet'),
      ).called(1);
    });

    test('forwards a secret lookup failure and never creates', () async {
      when(
        () => secretUsecase.resolve(any(), walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => const Err(SpUnexpected('lookup failed')));

      final result = await run();

      expect((result as Err).failure, isA<SpUnexpected>());
      expect(accountRepo.createCount, 0);
    });

    test('reports recovery required when native creation fails', () async {
      accountRepo.createShouldFail = true;

      final result = await run();

      expect((result as Err).failure, isA<SpRecoveryRequired>());
    });

    test(
      'preserves the config and pending directory on native failure',
      () async {
        accountRepo.createShouldFail = true;
        final result = await run();
        expect((result as Err).failure, isA<SpRecoveryRequired>());
        final stored =
            (await configRepo.fetch()) as Ok<SpBackendConfig?, SpFailure>;
        expect(stored.value, isNotNull);
        expect(accountRepo.accountDir, isTrue);
      },
    );

    test('a save failure returns Err and never reaches create', () async {
      configRepo.saveShouldFail = true;

      final result = await run();

      expect((result as Err).failure, isA<SpUnexpected>());
      expect(accountRepo.createCount, 0, reason: 'save is before create');
    });

    test(
      'a secret lookup throw returns Err (execute is total, does not throw)',
      () async {
        when(
          () => secretUsecase.resolve(any(), walletId: any(named: 'walletId')),
        ).thenThrow(Exception('secret read failed'));

        final result = await run();

        final failure = (result as Err).failure;
        expect(failure, isA<SpUnexpected>());
        expect(
          failure.logMessage,
          'SP wallet create failed',
          reason:
              'the block opens the account from the secret, so nothing caught may be '
              'written to the exportable log',
        );
        expect(accountRepo.createCount, 0);
      },
    );

    test('happy path returns Ok and persists the checked config', () async {
      final result = await run();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(accountRepo.createCount, 1);
      final stored =
          (await configRepo.fetch()) as Ok<SpBackendConfig?, SpFailure>;
      expect(stored.value?.network, BitcoinNetwork.regtest);
      expect(stored.value?.blindbitUrl, 'http://blindbit.example');
    });
  });

  group('CreateSpWalletUsecase setup status', () {
    test('is not set up before create', () {
      expect(configRepo.isSetUpNow, isFalse);
    });

    test('is set up synchronously once create returns Ok', () async {
      final result = await run();

      expect(result, isA<Ok<void, SpFailure>>());
      // The route gate reads this synchronously, so it has to be true by the
      // time the caller navigates, not a few turns later.
      expect(configRepo.isSetUpNow, isTrue);
    });

    test('stays not set up when create fails', () async {
      accountRepo.createShouldFail = true;

      final result = await run();

      expect(result, isA<Err<void, SpFailure>>());
      expect(configRepo.isSetUpNow, isFalse);
    });
  });

  group('CreateSpWalletUsecase scan cursor seeding', () {
    test('scanFromNow seeds the cursor at the live tip', () async {
      accountRepo.currentBlockHeightValue = 912345;

      final result = await run(scanFromNow: true);

      expect(result, isA<Ok<void, SpFailure>>());
      expect(accountRepo.scanOnceCount, 1);
      expect(accountRepo.lastScanStartHeight, 912345);
    });

    test('without scanFromNow nothing is scanned', () async {
      accountRepo.currentBlockHeightValue = 912345;

      final result = await run();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(accountRepo.scanOnceCount, 0);
      expect(accountRepo.lastScanStartHeight, isNull);
    });

    test('a tip read throw still returns Ok, the wallet exists', () async {
      accountRepo.currentBlockHeightShouldFail = true;

      final result = await run(scanFromNow: true);

      expect(result, isA<Ok<void, SpFailure>>());
      expect(accountRepo.createCount, 1);
      expect(accountRepo.scanOnceCount, 0);
    });
  });
}
