import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/recreate_sp_wallet_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart' show Secret;

import '../../sp_fakes.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

class _MockEnsureSpSessionUsecase extends Mock
    implements EnsureSpSessionUsecase {}

// The previous (pre-recreate) config, distinct from the new URLs each test
// passes to execute().
SpBackendConfig _previousConfig() => spBackendConfig(
  network: BitcoinNetwork.mainnet,
  blindbitUrl: 'http://blindbit.old',
  electrumUrl: 'tcp://electrum.old:50001',
);

// Orchestration-level tests: the backup/restore/discard filesystem work lives
// in BwkSpAccountRepository and is covered by its own test. Here we only assert
// the use case wires dispose/backup/create/discard (and the rollback) in the
// right order.
void main() {
  late MockGetSpSecretUsecase getSpSecretUsecase;
  late Secret secret;
  late MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late _MockEnsureSpSessionUsecase ensureSpSessionUsecase;
  late RecreateSpWalletUsecase usecase;

  setUpAll(() async {
    registerFallbackValue(await spSecret());
    registerFallbackValue(BitcoinNetwork.regtest);
    registerFallbackValue(spBackendConfig());
    registerFallbackValue(spSourceBinding);
    registerFallbackValue(
      SpBackendConfig(
        network: BitcoinNetwork.regtest,
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      ),
    );
  });

  setUp(() async {
    secret = await spSecret();
    getSpSecretUsecase = MockGetSpSecretUsecase();
    repository = MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    ensureSpSessionUsecase = _MockEnsureSpSessionUsecase();
    usecase = RecreateSpWalletUsecase(
      walletMutationGuard: WalletMutationGuard(),
      getSpSecretUsecase: getSpSecretUsecase,
      repository: repository,
      files: repository,
      configRepository: configRepository,
      ensureSpSessionUsecase: ensureSpSessionUsecase,
      guard: SpSessionGuard(),
    );

    when(
      () => getSpSecretUsecase.resolve(
        any(),
        walletId: any(named: 'walletId'),
        expected: any(named: 'expected'),
      ),
    ).thenAnswer((_) async => Ok((secret: secret, binding: spSourceBinding)));
    when(() => repository.beginTeardown()).thenReturn(null);
    when(() => repository.endTeardown()).thenReturn(null);
    when(() => repository.dispose()).thenAnswer((_) async => const Ok(null));
    when(
      () => repository.createAccountDir(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => repository.backupAccountDir(any()),
    ).thenAnswer((_) async => const Ok(true));
    when(
      () => repository.restoreAccountDir(any()),
    ).thenAnswer((_) async => const Ok(true));
    when(
      () => repository.discardBackup(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => configRepository.fetch()).thenAnswer(
      (_) async => Ok<SpBackendConfig?, SpFailure>(_previousConfig()),
    );
    when(
      () => configRepository.save(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => ensureSpSessionUsecase.execute(
        allowDuringTeardown: any(named: 'allowDuringTeardown'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => repository.createFromSecret(
        expectedConfig: any(named: 'expectedConfig'),
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        secret: any(named: 'secret'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  });

  test('rejects a network change before disposing the account', () async {
    final result = await usecase.execute(
      network: BitcoinNetwork.regtest,
      blindbitUrl: 'https://blindbit.example',
      electrumUrl: 'ssl://electrum.example:50002',
    );
    expect((result as Err).failure, isA<SpConfigInvalid>());
    verifyNever(() => repository.dispose());
    verifyNever(() => repository.backupAccountDir(any()));
  });

  test(
    'recreates: dispose, backup, save config, create, discard backup',
    () async {
      final result = await usecase.execute(
        network: BitcoinNetwork.mainnet,
        blindbitUrl: 'https://blindbit.example',
        electrumUrl: 'ssl://electrum.example:50002',
      );

      expect(result, isA<Ok<void, SpFailure>>());
      verifyInOrder([
        () => repository.beginTeardown(),
        () => repository.dispose(),
        () => repository.backupAccountDir(any()),
        () => configRepository.save(
          any(
            that: isA<SpBackendConfig>()
                .having((c) => c.network, 'network', BitcoinNetwork.mainnet)
                .having(
                  (c) => c.blindbitUrl,
                  'blindbitUrl',
                  'https://blindbit.example',
                )
                .having(
                  (c) => c.electrumUrl,
                  'electrumUrl',
                  'ssl://electrum.example:50002',
                ),
          ),
        ),
        () => repository.createFromSecret(
          expectedConfig: any(named: 'expectedConfig'),
          network: BitcoinNetwork.mainnet,
          blindbitUrl: 'https://blindbit.example',
          electrumUrl: 'ssl://electrum.example:50002',
          secret: any(named: 'secret'),
        ),
        () => repository.discardBackup(any()),
        () => repository.endTeardown(),
      ]);
      verifyNever(() => repository.restoreAccountDir(any()));
    },
  );

  test(
    'native failure retains backup and does not restore or discard',
    () async {
      when(
        () => repository.createFromSecret(
          expectedConfig: any(named: 'expectedConfig'),
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          secret: any(named: 'secret'),
        ),
      ).thenAnswer((_) async => const Err(SpSourceMismatch()));
      final result = await usecase.execute(
        network: BitcoinNetwork.mainnet,
        blindbitUrl: 'https://blindbit.example',
        electrumUrl: 'ssl://electrum.example:50002',
      );
      expect((result as Err).failure, isA<SpSourceMismatch>());
      verifyNever(() => repository.restoreAccountDir(any()));
      verifyNever(() => repository.discardBackup(any()));
      verifyNever(() => configRepository.save(_previousConfig()));
      verify(() => repository.endTeardown()).called(1);
    },
  );

  test('rollback releases the teardown bracket exactly once', () async {
    when(
      () => repository.createFromSecret(
        expectedConfig: any(named: 'expectedConfig'),
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        secret: any(named: 'secret'),
      ),
    ).thenAnswer((_) async => const Err(SpUnexpected('create failed')));

    final result = await usecase.execute(
      network: BitcoinNetwork.mainnet,
      blindbitUrl: 'https://blindbit.example',
      electrumUrl: 'ssl://electrum.example:50002',
    );

    expect(result, isA<Err<void, SpFailure>>());
    // Released once, by the outer finally. A second release inside the rollback
    // would unblock every other establishment across the awaits there, and with
    // a concurrent revoke would decrement a depth this frame does not own.
    verify(() => repository.endTeardown()).called(1);
  });

  test('missing previous config refuses recreation without deletion', () async {
    // No previous source identity may be inferred or deleted.
    when(
      () => configRepository.fetch(),
    ).thenAnswer((_) async => const Ok<SpBackendConfig?, SpFailure>(null));
    when(
      () => configRepository.delete(),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => repository.restoreAccountDir(any()),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => repository.createFromSecret(
        expectedConfig: any(named: 'expectedConfig'),
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        secret: any(named: 'secret'),
      ),
    ).thenAnswer((_) async => const Err(SpUnexpected('create failed')));

    final result = await usecase.execute(
      network: BitcoinNetwork.mainnet,
      blindbitUrl: 'https://blindbit.example',
      electrumUrl: 'ssl://electrum.example:50002',
    );

    expect(result, isA<Err<void, SpFailure>>());
    verifyNever(() => configRepository.delete());
    verifyNever(() => repository.backupAccountDir(any()));
  });

  test(
    'a dispose throw returns Err (execute is total) and clears teardown',
    () async {
      when(() => repository.dispose()).thenThrow(Exception('dispose boom'));

      final result = await usecase.execute(
        network: BitcoinNetwork.mainnet,
        blindbitUrl: 'https://blindbit.example',
        electrumUrl: 'ssl://electrum.example:50002',
      );

      expect((result as Err).failure, isA<SpUnexpected>());
      verify(() => repository.endTeardown()).called(1);
    },
  );

  test('a backup throw returns Err (execute is total)', () async {
    when(
      () => repository.backupAccountDir(any()),
    ).thenThrow(Exception('backup boom'));

    final result = await usecase.execute(
      network: BitcoinNetwork.mainnet,
      blindbitUrl: 'https://blindbit.example',
      electrumUrl: 'ssl://electrum.example:50002',
    );

    final failure = (result as Err).failure;
    expect(failure, isA<SpUnexpected>());
    expect(
      failure.logMessage,
      'SP wallet recreate failed',
      reason:
          'the block opens the account from the secret, so nothing caught may be '
          'written to the exportable log',
    );
    verify(() => repository.endTeardown()).called(1);
  });

  test('an invalid config aborts before the session is torn down', () async {
    // Validated before beginTeardown, so a bad config leaves the live session
    // and the account dir alone instead of unwinding a half-done recreate.
    final result = await usecase.execute(
      network: BitcoinNetwork.mainnet,
      blindbitUrl: '',
      electrumUrl: 'ssl://electrum.example:50002',
    );

    expect((result as Err).failure, isA<SpConfigInvalid>());
    verifyNever(() => repository.beginTeardown());
    verifyNever(() => repository.dispose());
    verifyNever(() => repository.backupAccountDir(any()));
    verifyNever(() => configRepository.save(any()));
  });
}
