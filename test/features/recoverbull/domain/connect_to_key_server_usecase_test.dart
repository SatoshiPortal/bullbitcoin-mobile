import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/connect_to_key_server_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

class _MockCheckServerConnection extends Mock
    implements CheckServerConnectionUsecase {}

class _MockEnsureRecoverBullTorSession extends Mock
    implements EnsureRecoverBullTorSessionUsecase {}

void main() {
  late _MockCheckServerConnection checkConnection;
  late _MockEnsureRecoverBullTorSession ensureSession;
  late RecoverBullTorRoute route;
  late int closeCount;
  late List<Duration> waited;
  late List<int> attempts;
  late ConnectToKeyServerUsecase usecase;

  setUp(() {
    checkConnection = _MockCheckServerConnection();
    ensureSession = _MockEnsureRecoverBullTorSession();
    closeCount = 0;
    route = RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.direct,
      ),
      () async => closeCount++,
    );
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(route));
    waited = [];
    attempts = [];
    usecase = ConnectToKeyServerUsecase(
      checkConnection,
      ensureSession,
      wait: (duration) async => waited.add(duration),
    );
  });

  Future<Result<bool, RecoverBullCoreFailure>> run() =>
      usecase.execute(onAttempt: attempts.add);

  test('stops at the first answer instead of exhausting the budget', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    expect(await run(), isA<Ok<bool, RecoverBullCoreFailure>>());
    expect(attempts, [1]);
    verify(() => checkConnection.execute(route: route)).called(1);
    verify(() => ensureSession.execute()).called(1);
    expect(closeCount, 1);
  });

  test('gives up after the attempt budget', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(false));

    expect(await run(), isA<Ok<bool, RecoverBullCoreFailure>>());
    expect(attempts, [1, 2, 3]);
    expect(attempts.length, ConnectToKeyServerUsecase.maxAttempts);
    verify(
      () => checkConnection.execute(route: route),
    ).called(ConnectToKeyServerUsecase.maxAttempts);
    verify(() => ensureSession.execute()).called(1);
    expect(closeCount, 1);
  });

  test(
    'reports the attempt that is in flight, not the one that failed',
    () async {
      var calls = 0;
      when(() => checkConnection.execute(route: route)).thenAnswer((_) async {
        // The attempt must already be published when the call runs, otherwise
        // the screen names the previous one.
        expect(attempts.last, calls + 1);
        calls++;
        return Ok(calls == 2);
      });

      expect(await run(), isA<Ok<bool, RecoverBullCoreFailure>>());
      expect(attempts, [1, 2]);
      verify(() => checkConnection.execute(route: route)).called(2);
      expect(closeCount, 1);
    },
  );

  test('tries immediately, then backs off between retries', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(false));

    await run();

    expect(waited, const [Duration(seconds: 1), Duration(seconds: 2)]);
    expect(closeCount, 1);
  });

  test('does not delay a server that answers at once', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    await run();

    expect(waited, isEmpty);
    expect(closeCount, 1);
  });

  test('does not retry an unavailable external proxy', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Err(ExternalTorProxyUnavailableFailure()));

    final result = await usecase.execute(onAttempt: attempts.add);

    expect(result, isA<Err<bool, RecoverBullCoreFailure>>());
    expect(attempts, [1]);
    expect(waited, isEmpty);
    expect(closeCount, 1);
  });

  test('retries checker failures, then closes the route', () async {
    when(() => checkConnection.execute(route: route)).thenAnswer(
      (_) async => const Err(KeyServerUnavailableFailure('timeout')),
    );

    final result = await run();

    expect(result, isA<Ok<bool, RecoverBullCoreFailure>>());
    expect(attempts, [1, 2, 3]);
    verify(
      () => checkConnection.execute(route: route),
    ).called(ConnectToKeyServerUsecase.maxAttempts);
    expect(closeCount, 1);
  });

  test(
    'external session failure stops before checking and does not close',
    () async {
      when(() => ensureSession.execute()).thenAnswer(
        (_) async => const Err(ExternalTorProxyUnavailableFailure()),
      );

      final result = await run();

      expect(result, isA<Err<bool, RecoverBullCoreFailure>>());
      expect(attempts, [1]);
      verifyNever(() => checkConnection.execute(route: any(named: 'route')));
      expect(closeCount, 0);
    },
  );

  test('awaits close and does not let a close error mask success', () async {
    var closeStarted = false;
    var releaseClose = false;
    route = RecoverBullTorRoute(route.route, () async {
      closeStarted = true;
      while (!releaseClose) {
        await Future<void>.delayed(Duration.zero);
      }
      throw Exception('close failed');
    });
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(route));
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    final future = run();
    await Future<void>.delayed(Duration.zero);
    expect(closeStarted, isTrue);
    releaseClose = true;

    expect(await future, isA<Ok<bool, RecoverBullCoreFailure>>());
  });
}
