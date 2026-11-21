import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/update_sp_backend_config_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secret;

import '../../sp_fakes.dart';

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

class _MockEnsureSpSessionUsecase extends Mock
    implements EnsureSpSessionUsecase {}

void main() {
  final previous = spBackendConfig(
    network: BitcoinNetwork.mainnet,
    blindbitUrl: 'https://blindbit.old',
    electrumUrl: 'ssl://electrum.old:50002',
  );
  final next = spBackendConfig(
    network: BitcoinNetwork.mainnet,
    blindbitUrl: 'https://blindbit.new',
    electrumUrl: 'ssl://electrum.new:50002',
  );
  late Secret secret;
  late MockGetSpSecretUsecase secretUsecase;
  late MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late _MockEnsureSpSessionUsecase ensureSession;
  late UpdateSpBackendConfigUsecase usecase;
  late SpBackendConfig? stored;

  Future<Result<bool, SpFailure>> update({
    String? blindbitUrl,
    String? electrumUrl,
  }) => usecase.execute(
    network: next.network,
    blindbitUrl: blindbitUrl ?? next.blindbitUrl,
    electrumUrl: electrumUrl ?? next.electrumUrl,
  );

  Future<Result<void, SpFailure>> openNext() => repository.createFromSecret(
    network: next.network,
    secret: secret,
    blindbitUrl: next.blindbitUrl,
    electrumUrl: next.electrumUrl,
  );

  setUpAll(() async {
    secret = await spSecret();
    registerFallbackValue(previous);
  });

  setUp(() {
    secretUsecase = MockGetSpSecretUsecase();
    repository = MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    ensureSession = _MockEnsureSpSessionUsecase();
    stored = previous;
    usecase = UpdateSpBackendConfigUsecase(
      getSpFeatureGateUsecase: FakeSpFeatureGateUsecase(),
      getSpSecretUsecase: secretUsecase,
      repository: repository,
      files: repository,
      configRepository: configRepository,
      ensureSpSessionUsecase: ensureSession,
      isSpScanningUsecase: IsSpScanningUsecase(repository: repository),
      guard: SpSessionGuard(),
    );

    when(() => configRepository.fetch()).thenAnswer((_) async => Ok(stored));
    when(() => configRepository.save(any())).thenAnswer((call) async {
      stored = call.positionalArguments.single as SpBackendConfig;
      return const Ok(null);
    });
    when(() => repository.isScanningCached).thenReturn(false);
    when(() => repository.beginTeardown()).thenReturn(null);
    when(() => repository.endTeardown()).thenReturn(null);
    when(() => repository.dispose()).thenAnswer((_) async => const Ok(null));
    when(() => repository.hasRevokedSentinel())
        .thenAnswer((_) async => const Ok(false));
    when(() => repository.adoptNewestBackup())
        .thenAnswer((_) async => const Ok(false));
    when(() => repository.accountDirExists())
        .thenAnswer((_) async => const Ok(true));
    when(() => ensureSession.execute(allowDuringTeardown: true))
        .thenAnswer((_) async => Ok(spWallet()));
    when(() => secretUsecase.execute(next.network))
        .thenAnswer((_) async => Ok(secret));
    when(openNext).thenAnswer((_) async => const Ok(null));
  });

  test('cold reconfigure opens only the replacement endpoints', () async {
    expect(await update(), const Ok<bool, SpFailure>(true));

    verifyInOrder([
      () => repository.beginTeardown(),
      () => repository.dispose(),
      () => configRepository.save(next),
      openNext,
      () => repository.endTeardown(),
    ]);
    verifyNever(() => ensureSession.execute());
    expect(stored, next);
  });

  test('unchanged settings leave the live session alone', () async {
    expect(
      await update(
        blindbitUrl: previous.blindbitUrl,
        electrumUrl: previous.electrumUrl,
      ),
      const Ok<bool, SpFailure>(false),
    );
    verifyZeroInteractions(secretUsecase);
    verifyNever(() => repository.dispose());
    verifyNever(() => configRepository.save(any()));
  });

  test('changing the scan minimum reopens with the saved servers', () async {
    final replacement = SpBackendConfig(
      network: previous.network,
      blindbitUrl: previous.blindbitUrl,
      electrumUrl: previous.electrumUrl,
      fetchConcurrencyFactor: 6,
      matchConcurrencyFactor: 2,
      minScanAmountSat: 600,
    );
    stored = SpBackendConfig(
      network: previous.network,
      blindbitUrl: previous.blindbitUrl,
      electrumUrl: previous.electrumUrl,
      fetchConcurrencyFactor: replacement.fetchConcurrencyFactor,
      matchConcurrencyFactor: replacement.matchConcurrencyFactor,
    );
    Future<Result<void, SpFailure>> reopen() => repository.createFromSecret(
      network: replacement.network,
      secret: secret,
      blindbitUrl: replacement.blindbitUrl,
      electrumUrl: replacement.electrumUrl,
      fetchConcurrencyFactor: replacement.fetchConcurrencyFactor,
      matchConcurrencyFactor: replacement.matchConcurrencyFactor,
      minScanAmountSat: replacement.minScanAmountSat,
    );
    when(reopen).thenAnswer((_) async => const Ok(null));

    expect(
      await usecase.setMinScanAmount(
        network: previous.network,
        minScanAmountSat: replacement.minScanAmountSat,
      ),
      const Ok<bool, SpFailure>(true),
    );
    verify(reopen).called(1);
    expect(stored, replacement);
  });

  test('saving server URLs preserves a custom scan minimum', () async {
    stored = spBackendConfig(
      network: previous.network,
      blindbitUrl: previous.blindbitUrl,
      electrumUrl: previous.electrumUrl,
      minScanAmountSat: 600,
    );
    when(
      () => repository.createFromSecret(
        network: next.network,
        secret: secret,
        blindbitUrl: next.blindbitUrl,
        electrumUrl: next.electrumUrl,
        minScanAmountSat: 600,
      ),
    ).thenAnswer((_) async => const Ok(null));

    expect(await update(), const Ok<bool, SpFailure>(true));
    expect(stored?.minScanAmountSat, 600);
  });

  test(
    'a failed replacement open restores the original saved config',
    () async {
      const failure = SpUnexpected('open failed');
      when(openNext).thenAnswer((_) async => const Err(failure));

      expect((await update() as Err<bool, SpFailure>).failure, failure);

      verifyInOrder([
        () => configRepository.save(next),
        openNext,
        () => repository.dispose(),
        () => configRepository.save(previous),
        () => ensureSession.execute(allowDuringTeardown: true),
        () => repository.endTeardown(),
      ]);
      expect(stored, previous);
    },
  );

  test(
    'a failed config write reopens without rewriting the original',
    () async {
      const failure = SpUnexpected('write failed');
      when(() => configRepository.save(next))
          .thenAnswer((_) async => const Err(failure));

      expect((await update() as Err<bool, SpFailure>).failure, failure);

      verifyNever(openNext);
      verifyNever(() => configRepository.save(previous));
      verify(() => ensureSession.execute(allowDuringTeardown: true)).called(1);
      expect(stored, previous);
    },
  );

  test('rollback keeps settings for a replacement it cannot close', () async {
    const failure = SpUnexpected('replacement failed after opening');
    when(openNext).thenAnswer((_) async {
      expect(stored, next);
      when(() => repository.dispose())
          .thenAnswer((_) async => const Err(SpSessionBusy()));
      return const Err(failure);
    });

    expect((await update() as Err<bool, SpFailure>).failure, failure);

    expect(stored, next);
    verifyNever(() => configRepository.save(previous));
    verifyZeroInteractions(ensureSession);
  });

  test('rejects a scan that starts during secret lookup', () async {
    when(() => secretUsecase.execute(next.network)).thenAnswer((_) async {
      when(() => repository.isScanningCached).thenReturn(true);
      return Ok(secret);
    });

    expect((await update() as Err<bool, SpFailure>).failure, isA<SpScanBusy>());
    verifyNever(() => repository.dispose());
    verifyNever(() => configRepository.save(any()));
  });

  test('no saved settings cannot create a new wallet', () async {
    stored = null;
    expect((await update() as Err<bool, SpFailure>).failure, isA<SpNotSetUp>());
    verifyZeroInteractions(ensureSession);
    verifyNever(() => configRepository.save(any()));
  });

  test('a revoked wallet cannot be reopened by changing servers', () async {
    when(() => repository.hasRevokedSentinel())
        .thenAnswer((_) async => const Ok(true));
    expect((await update() as Err<bool, SpFailure>).failure, isA<SpNotSetUp>());
    verifyNever(() => repository.dispose());
    verifyNever(() => configRepository.save(any()));
  });

  test('a recovered backup is checked for revocation before open', () async {
    var adopted = false;
    when(() => repository.adoptNewestBackup()).thenAnswer((_) async {
      adopted = true;
      return const Ok(true);
    });
    when(() => repository.hasRevokedSentinel())
        .thenAnswer((_) async => Ok(adopted));

    expect((await update() as Err<bool, SpFailure>).failure, isA<SpNotSetUp>());
    verifyNever(openNext);
    verifyNever(() => configRepository.save(any()));
  });

  test('a dispose failure leaves the stored config alone', () async {
    const failure = SpSessionBusy();
    when(() => repository.dispose())
        .thenAnswer((_) async => const Err(failure));

    expect((await update() as Err<bool, SpFailure>).failure, failure);

    verifyNever(openNext);
    verifyNever(() => configRepository.save(any()));
    verify(() => repository.endTeardown()).called(1);
  });
}
