import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/recreate_sp_wallet_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

class _MockEnsureSpSessionUsecase extends Mock
    implements EnsureSpSessionUsecase {}

// The previous (pre-recreate) config, distinct from the new URLs each test
// passes to execute().
SpBackendConfig _previousConfig() => spBackendConfig(
  blindbitUrl: 'http://blindbit.old',
  electrumUrl: 'tcp://electrum.old:50001',
);

// Orchestration-level tests: the backup/restore/discard filesystem work lives
// in BwkSpAccountRepository and is covered by its own test. Here we only assert
// the use case wires dispose/backup/create/discard (and the rollback) in the
// right order.
void main() {
  late MockGetDefaultSeedUsecase getDefaultSeedUsecase;
  late MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late _MockEnsureSpSessionUsecase ensureSpSessionUsecase;
  late RecreateSpWalletUsecase usecase;

  setUpAll(() {
    registerFallbackValue(BitcoinNetwork.regtest);
    registerFallbackValue(
      SpBackendConfig(
        network: BitcoinNetwork.regtest,
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      ),
    );
  });

  setUp(() {
    getDefaultSeedUsecase = MockGetDefaultSeedUsecase();
    repository = MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    ensureSpSessionUsecase = _MockEnsureSpSessionUsecase();
    usecase = RecreateSpWalletUsecase(
      getDefaultSeedUsecase: getDefaultSeedUsecase,
      repository: repository,
      files: repository,
      configRepository: configRepository,
      ensureSpSessionUsecase: ensureSpSessionUsecase,
      guard: SpSessionGuard(),
    );

    when(
      () => getDefaultSeedUsecase.execute(),
    ).thenAnswer((_) async => spMnemonicSeed());
    when(() => repository.beginTeardown()).thenReturn(null);
    when(() => repository.endTeardown()).thenReturn(null);
    when(() => repository.dispose()).thenAnswer((_) async => const Ok(null));
    when(
      () => repository.backupAccountDir(),
    ).thenAnswer((_) async => const Ok(true));
    when(
      () => repository.restoreAccountDir(),
    ).thenAnswer((_) async => const Ok(true));
    when(
      () => repository.discardBackup(),
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
      () => repository.createFromMnemonic(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        mnemonic: any(named: 'mnemonic'),
      ),
    ).thenAnswer((_) async => const Ok(null));
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
        () => repository.backupAccountDir(),
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
        () => repository.createFromMnemonic(
          network: BitcoinNetwork.mainnet,
          blindbitUrl: 'https://blindbit.example',
          electrumUrl: 'ssl://electrum.example:50002',
          mnemonic: any(named: 'mnemonic'),
        ),
        () => repository.discardBackup(),
        () => repository.endTeardown(),
      ]);
      verifyNever(() => repository.restoreAccountDir());
    },
  );

  test(
    'rolls back when the create fails: restores the dir, re-saves the '
    'previous config, then re-establishes before releasing the teardown',
    () async {
      when(
        () => repository.createFromMnemonic(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          mnemonic: any(named: 'mnemonic'),
        ),
      ).thenAnswer((_) async => const Err(SpUnexpected('create failed')));

      final result = await usecase.execute(
        network: BitcoinNetwork.mainnet,
        blindbitUrl: 'https://blindbit.example',
        electrumUrl: 'ssl://electrum.example:50002',
      );

      expect(result, isA<Err<void, SpFailure>>());
      // The previous config is re-saved, then the session is re-established
      // with the bracket still held: only the outer finally releases it.
      // (verifyInOrder runs first: a standalone verify would mark the call and
      // break ordering.)
      verifyInOrder([
        () => repository.restoreAccountDir(),
        () => configRepository.save(_previousConfig()),
        () => ensureSpSessionUsecase.execute(allowDuringTeardown: true),
        () => repository.endTeardown(),
      ]);
      // Two disposes: the pre-backup one and the rollback one before restore.
      verify(() => repository.dispose()).called(2);
      verifyNever(() => repository.discardBackup());
    },
  );

  test(
    'rollback without a backup still reverts config but skips re-establish',
    () async {
      when(
        () => repository.restoreAccountDir(),
      ).thenAnswer((_) async => const Ok(false));
      when(
        () => repository.createFromMnemonic(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          mnemonic: any(named: 'mnemonic'),
        ),
      ).thenAnswer((_) async => const Err(SpUnexpected('create failed')));

      final result = await usecase.execute(
        network: BitcoinNetwork.mainnet,
        blindbitUrl: 'https://blindbit.example',
        electrumUrl: 'ssl://electrum.example:50002',
      );

      expect(result, isA<Err<void, SpFailure>>());
      verify(() => repository.restoreAccountDir()).called(1);
      // Config is always reverted so the failed new config never lingers, but with
      // no restored dir the session is not re-established.
      verify(() => configRepository.save(_previousConfig())).called(1);
      verifyNever(() => ensureSpSessionUsecase.execute());
    },
  );

  test('rollback releases the teardown bracket exactly once', () async {
    when(
      () => repository.createFromMnemonic(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        mnemonic: any(named: 'mnemonic'),
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

  test(
    'rollback with no previous config deletes it (no persisted new config)',
    () async {
      // A corrupt/absent previous config: the fetch folds to null, so the rollback
      // must delete() rather than re-save, leaving the wallet not-set-up.
      when(
        () => configRepository.fetch(),
      ).thenAnswer((_) async => const Ok<SpBackendConfig?, SpFailure>(null));
      when(
        () => configRepository.delete(),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => repository.restoreAccountDir(),
      ).thenAnswer((_) async => const Ok(false));
      when(
        () => repository.createFromMnemonic(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          mnemonic: any(named: 'mnemonic'),
        ),
      ).thenAnswer((_) async => const Err(SpUnexpected('create failed')));

      final result = await usecase.execute(
        network: BitcoinNetwork.mainnet,
        blindbitUrl: 'https://blindbit.example',
        electrumUrl: 'ssl://electrum.example:50002',
      );

      expect(result, isA<Err<void, SpFailure>>());
      verify(() => configRepository.delete()).called(1);
    },
  );

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
      () => repository.backupAccountDir(),
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
          'the block derives the mnemonic, so nothing caught may be '
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
    verifyNever(() => repository.backupAccountDir());
    verifyNever(() => configRepository.save(any()));
  });
}
