import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/recreate_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

class _MockSpAccountRepository extends Mock implements SpAccountRepository {}

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

class _MockEnsureSpSessionUsecase extends Mock
    implements EnsureSpSessionUsecase {}

MnemonicSeed _seed() => MnemonicSeed(
  mnemonicWords: List.filled(12, 'abandon'),
  bytes: Uint8List.fromList(List.filled(64, 1)),
  masterFingerprint: 'f23f9fd2',
);

SpBackendConfig _config() => SpBackendConfig(
  network: SpNetwork.regtest,
  blindbitUrl: 'http://blindbit.old',
  electrumUrl: 'tcp://electrum.old:50001',
);

// Orchestration-level tests: the backup/restore/discard filesystem work lives
// in BwkSpAccountRepository and is covered by its own test. Here we only assert
// the use case wires dispose/backup/create/discard (and the rollback) in the
// right order.
void main() {
  late _MockGetDefaultSeedUsecase getDefaultSeedUsecase;
  late _MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late _MockEnsureSpSessionUsecase ensureSpSessionUsecase;
  late RecreateSpWalletUsecase usecase;

  setUpAll(() {
    registerFallbackValue(SpNetwork.regtest);
    registerFallbackValue(
      SpBackendConfig(
        network: SpNetwork.regtest,
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      ),
    );
  });

  setUp(() {
    getDefaultSeedUsecase = _MockGetDefaultSeedUsecase();
    repository = _MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    ensureSpSessionUsecase = _MockEnsureSpSessionUsecase();
    usecase = RecreateSpWalletUsecase(
      getDefaultSeedUsecase: getDefaultSeedUsecase,
      repository: repository,
      configRepository: configRepository,
      ensureSpSessionUsecase: ensureSpSessionUsecase,
    );

    when(
      () => getDefaultSeedUsecase.execute(),
    ).thenAnswer((_) async => _seed());
    when(() => repository.beginTeardown()).thenReturn(null);
    when(() => repository.endTeardown()).thenReturn(null);
    when(() => repository.dispose()).thenAnswer((_) async {});
    when(() => repository.backupAccountDir()).thenAnswer((_) async => true);
    when(() => repository.restoreAccountDir()).thenAnswer((_) async => true);
    when(() => repository.discardBackup()).thenAnswer((_) async {});
    when(() => configRepository.fetch())
        .thenAnswer((_) async => Ok<SpBackendConfig?, SpFailure>(_config()));
    when(() => configRepository.save(any())).thenAnswer((_) async {});
    when(() => ensureSpSessionUsecase.execute()).thenAnswer((_) async => null);
    when(
      () => repository.createFromMnemonic(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        mnemonic: any(named: 'mnemonic'),
      ),
    ).thenAnswer((_) async {});
  });

  test('recreates: dispose, backup, save config, create, discard backup',
      () async {
    final result = await usecase.execute(
      network: SpNetwork.bitcoin,
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
                  .having((c) => c.network, 'network', SpNetwork.bitcoin)
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
            network: SpNetwork.bitcoin,
            blindbitUrl: 'https://blindbit.example',
            electrumUrl: 'ssl://electrum.example:50002',
            mnemonic: any(named: 'mnemonic'),
          ),
      () => repository.discardBackup(),
      () => repository.endTeardown(),
    ]);
    verifyNever(() => repository.restoreAccountDir());
  });

  test('rolls back when the create fails: restores the dir, re-saves the '
      'previous config, clears teardown, then re-establishes the session',
      () async {
    when(
      () => repository.createFromMnemonic(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        mnemonic: any(named: 'mnemonic'),
      ),
    ).thenThrow(Exception('create failed'));

    final result = await usecase.execute(
      network: SpNetwork.bitcoin,
      blindbitUrl: 'https://blindbit.example',
      electrumUrl: 'ssl://electrum.example:50002',
    );

    expect(result, isA<Err<void, SpFailure>>());
    // The previous config is re-saved and endTeardown runs BEFORE the
    // re-establish so EnsureSpSessionUsecase does not refuse. (verifyInOrder
    // runs first: a standalone verify would mark the call and break ordering.)
    verifyInOrder([
      () => repository.restoreAccountDir(),
      () => configRepository.save(_config()),
      () => repository.endTeardown(),
      () => ensureSpSessionUsecase.execute(),
    ]);
    // Two disposes: the pre-backup one and the rollback one before restore.
    verify(() => repository.dispose()).called(2);
    verifyNever(() => repository.discardBackup());
  });

  test('rollback without a backup still reverts config but skips re-establish',
      () async {
    when(() => repository.restoreAccountDir()).thenAnswer((_) async => false);
    when(
      () => repository.createFromMnemonic(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        mnemonic: any(named: 'mnemonic'),
      ),
    ).thenThrow(Exception('create failed'));

    final result = await usecase.execute(
      network: SpNetwork.bitcoin,
      blindbitUrl: 'https://blindbit.example',
      electrumUrl: 'ssl://electrum.example:50002',
    );

    expect(result, isA<Err<void, SpFailure>>());
    verify(() => repository.restoreAccountDir()).called(1);
    // Config is always reverted so the failed new config never lingers, but with
    // no restored dir the session is not re-established.
    verify(() => configRepository.save(_config())).called(1);
    verifyNever(() => ensureSpSessionUsecase.execute());
  });

  test('rollback with no previous config deletes it (no persisted new config)',
      () async {
    // A corrupt/absent previous config: the fetch folds to null, so the rollback
    // must delete() rather than re-save, leaving the wallet not-set-up.
    when(() => configRepository.fetch())
        .thenAnswer((_) async => const Ok<SpBackendConfig?, SpFailure>(null));
    when(() => configRepository.delete()).thenAnswer((_) async {});
    when(() => repository.restoreAccountDir()).thenAnswer((_) async => false);
    when(
      () => repository.createFromMnemonic(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        mnemonic: any(named: 'mnemonic'),
      ),
    ).thenThrow(Exception('create failed'));

    final result = await usecase.execute(
      network: SpNetwork.bitcoin,
      blindbitUrl: 'https://blindbit.example',
      electrumUrl: 'ssl://electrum.example:50002',
    );

    expect(result, isA<Err<void, SpFailure>>());
    verify(() => configRepository.delete()).called(1);
  });

  test('a dispose throw returns Err (execute is total) and clears teardown',
      () async {
    when(() => repository.dispose()).thenThrow(Exception('dispose boom'));

    final result = await usecase.execute(
      network: SpNetwork.bitcoin,
      blindbitUrl: 'https://blindbit.example',
      electrumUrl: 'ssl://electrum.example:50002',
    );

    expect((result as Err).failure, isA<SpUnexpected>());
    verify(() => repository.endTeardown()).called(1);
  });

  test('a backup throw returns Err (execute is total)', () async {
    when(() => repository.backupAccountDir())
        .thenThrow(Exception('backup boom'));

    final result = await usecase.execute(
      network: SpNetwork.bitcoin,
      blindbitUrl: 'https://blindbit.example',
      electrumUrl: 'ssl://electrum.example:50002',
    );

    expect((result as Err).failure, isA<SpUnexpected>());
    verify(() => repository.endTeardown()).called(1);
  });
}
