import 'dart:async';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart' show SilentPaymentDescriptors;

import '../../sp_fakes.dart';

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

void main() {
  late SilentPaymentDescriptors spScanKey;
  late MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late MockGetSpScanKeyUsecase getSpScanKeyUsecase;
  late EnsureSpSessionUsecase usecase;
  late SpSessionGuard guard;

  setUpAll(() async {
    registerFallbackValue(BitcoinNetwork.regtest);
    spScanKey = await deriveSpScanKey();
    registerFallbackValue(spScanKey);
  });

  setUp(() {
    repository = MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    getSpScanKeyUsecase = MockGetSpScanKeyUsecase();
    guard = SpSessionGuard();
    usecase = EnsureSpSessionUsecase(
      repository: repository,
      files: repository,
      configRepository: configRepository,
      getSpScanKeyUsecase: getSpScanKeyUsecase,
      guard: guard,
    );

    when(() => repository.hasSession).thenReturn(false);
    when(() => repository.teardownInProgress).thenReturn(false);
    when(
      () => repository.adoptNewestBackup(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => repository.hasRevokedSentinel(),
    ).thenAnswer((_) async => const Ok(false));
    when(() => repository.dispose()).thenAnswer((_) async => const Ok(null));
    when(() => repository.snapshot()).thenReturn(Ok(spWallet()));
    when(() => configRepository.fetch()).thenAnswer(
      (_) async => Ok<SpBackendConfig?, SpFailure>(spBackendConfig()),
    );
    when(
      () => getSpScanKeyUsecase.execute(network: any(named: 'network')),
    ).thenAnswer((_) async => Ok(spScanKey));
    when(
      () => repository.createFromScanKey(
        scanKey: any(named: 'scanKey'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  });

  for (final nativeFails in [false, true]) {
    test(
      'establishment holds the lifecycle guard through native creation (failure: $nativeFails)',
      () async {
        final entered = Completer<void>();
        final release = Completer<Result<void, SpFailure>>();
        when(
          () => repository.createFromScanKey(
            scanKey: any(named: 'scanKey'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
          ),
        ).thenAnswer((_) {
          entered.complete();
          return release.future;
        });
        final establishing = usecase.execute();
        await entered.future;
        var teardownStarted = false;
        final teardown = guard.exclusive(() async {
          teardownStarted = true;
        });
        await Future<void>.delayed(Duration.zero);
        expect(teardownStarted, isFalse);
        release.complete(
          nativeFails
              ? const Err(SpUnexpected('native create failed'))
              : const Ok(null),
        );
        await establishing;
        await teardown;
        expect(teardownStarted, isTrue);
      },
    );
  }

  test(
    'rollback bypasses both the owned guard and a queued public ensure',
    () async {
      when(
        () => repository.createFromScanKey(
          scanKey: any(named: 'scanKey'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      ).thenAnswer((_) async {
        when(() => repository.hasSession).thenReturn(true);
        return const Ok(null);
      });
      final entered = Completer<void>();
      final rollback = Completer<void>();
      final owner = guard.exclusive(() async {
        entered.complete();
        await rollback.future;
        return usecase.execute(allowDuringTeardown: true);
      });
      await entered.future;
      final queued = usecase.execute();
      rollback.complete();
      expect(
        await owner.timeout(const Duration(seconds: 1)),
        isA<Ok<SpWallet?, SpFailure>>(),
      );
      await queued.timeout(const Duration(seconds: 1));
      verify(
        () => repository.createFromScanKey(
          scanKey: any(named: 'scanKey'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      ).called(1);
    },
  );

  group('EnsureSpSessionUsecase', () {
    test('reuses the live session without reconstructing', () async {
      when(() => repository.hasSession).thenReturn(true);

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNotNull);
      verify(() => repository.snapshot()).called(1);
      verifyNever(
        () => repository.createFromScanKey(
          scanKey: any(named: 'scanKey'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      );
    });

    test('returns null when a .revoked sentinel is present', () async {
      when(
        () => repository.hasRevokedSentinel(),
      ).thenAnswer((_) async => const Ok(true));

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verifyNever(() => configRepository.fetch());
    });

    test('returns null when no backend config is stored', () async {
      when(
        () => configRepository.fetch(),
      ).thenAnswer((_) async => const Ok<SpBackendConfig?, SpFailure>(null));

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verifyNever(
        () => getSpScanKeyUsecase.execute(network: any(named: 'network')),
      );
    });

    for (final failure in const <SpFailure>[
      SpNoDefaultWallet('no default'),
      SpKeystoreLocked('KeystoreLockedFailure'),
      SpUnexpected('scan credential unavailable: UseSecretFailure'),
    ]) {
      test('a ${failure.runtimeType} from the scan credential is returned and '
          'nothing is created', () async {
        when(
          () => getSpScanKeyUsecase.execute(network: any(named: 'network')),
        ).thenAnswer((_) async => Err(failure));

        final result = await usecase.execute();

        expect((result as Err).failure, same(failure));
        verifyNever(
          () => repository.createFromScanKey(
            scanKey: any(named: 'scanKey'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
          ),
        );
      });
    }

    test('reconstructs via createFromScanKey from the stored config', () async {
      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNotNull);
      verify(
        () => getSpScanKeyUsecase.execute(network: BitcoinNetwork.regtest),
      ).called(1);
      verify(
        () => repository.createFromScanKey(
          scanKey: spScanKey,
          blindbitUrl: 'http://blindbit.example',
          electrumUrl: 'tcp://electrum.example:50001',
        ),
      ).called(1);
    });

    test('returns null while a teardown is in progress (no create)', () async {
      when(() => repository.teardownInProgress).thenReturn(true);

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verifyNever(() => configRepository.fetch());
      verifyNever(
        () => repository.createFromScanKey(
          scanKey: any(named: 'scanKey'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      );
    });

    test(
      'allowDuringTeardown establishes while the teardown is still held',
      () async {
        // The one caller that owns the teardown it runs inside: a failed recreate
        // rolling back has to bring the previous session back before releasing.
        when(() => repository.teardownInProgress).thenReturn(true);

        final result = await usecase.execute(allowDuringTeardown: true);

        expect((result as Ok<SpWallet?, SpFailure>).value, isNotNull);
        verify(
          () => repository.createFromScanKey(
            scanKey: any(named: 'scanKey'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
          ),
        ).called(1);
      },
    );

    test('a teardown that begins after the entry checks but before create '
        'aborts the create (TOCTOU)', () async {
      // teardownInProgress is false through the entry/establish checks; a
      // revoke/recreate flips it while the scan key derivation is in flight, so the
      // re-check right before create must abort instead of racing a live
      // session.
      var tearingDown = false;
      when(() => repository.teardownInProgress).thenAnswer((_) => tearingDown);
      when(
        () => getSpScanKeyUsecase.execute(network: any(named: 'network')),
      ).thenAnswer((_) async {
        tearingDown = true;
        return Ok(spScanKey);
      });

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verifyNever(
        () => repository.createFromScanKey(
          scanKey: any(named: 'scanKey'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      );
    });

    test('disposes a live session and returns null when the sentinel appeared '
        'after the session was established (a zombie session)', () async {
      // A revoke wrote the sentinel while a session was still live; ensure must
      // not keep serving it.
      when(() => repository.hasSession).thenReturn(true);
      when(
        () => repository.hasRevokedSentinel(),
      ).thenAnswer((_) async => const Ok(true));

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verify(() => repository.dispose()).called(1);
      verifyNever(() => repository.snapshot());
    });

    test(
      'serializes concurrent establishment into one createFromScanKey',
      () async {
        final results = await Future.wait([
          usecase.execute(),
          usecase.execute(),
        ]);

        expect((results[0] as Ok<SpWallet?, SpFailure>).value, isNotNull);
        expect((results[1] as Ok<SpWallet?, SpFailure>).value, isNotNull);
        verify(
          () => repository.createFromScanKey(
            scanKey: any(named: 'scanKey'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
          ),
        ).called(1);
      },
    );
  });
}
