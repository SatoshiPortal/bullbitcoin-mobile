import 'package:bull_recoverbull/src/domain/usecases/check_server_connection_usecase.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_recoverbull/src/domain/usecases/connect_to_key_server_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:io';

import 'package:bull_tor/tor.dart';
import '../../support/log_sink.dart';

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
  late TestLogSink log;
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
      HttpClient(),
    );
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(route));
    waited = [];
    attempts = [];
    log = TestLogSink.recording();
    usecase = ConnectToKeyServerUsecase(
      check: checkConnection,
      ensureTor: ensureSession,
      log: log,
      wait: (duration) async => waited.add(duration),
    );
  });

  setUpAll(() {
    registerFallbackValue(
      RecoverBullTorRoute(
        TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
          evidence: TorReadinessEvidence.embeddedBootstrap,
        ),
        () async {},
        HttpClient(),
      ),
    );
  });

  Future<Result<bool, RecoverBullFailure>> run() =>
      usecase.execute(onAttempt: attempts.add);

  test('temporary server pressure is preserved for the caller', () async {
    when(() => checkConnection.execute(route: route)).thenAnswer(
      (_) async => const Err(
        RecoverBullTemporarilyUnavailableFailure(
          retryIn: Duration(seconds: 30),
        ),
      ),
    );

    final result = await run();

    final failure = (result as Err<bool, RecoverBullFailure>).failure;
    expect(failure, isA<RecoverBullTemporarilyUnavailableFailure>());
    expect(
      (failure as RecoverBullTemporarilyUnavailableFailure).retryIn,
      const Duration(seconds: 30),
    );
  });

  test('stops at the first answer instead of exhausting the budget', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    expect(await run(), isA<Ok<bool, RecoverBullFailure>>());
    expect(attempts, [1]);
    verify(() => checkConnection.execute(route: route)).called(1);
    verify(() => ensureSession.execute()).called(1);
    expect(closeCount, 1);
  });

  test('gives up after the attempt budget', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(false));

    expect(await run(), isA<Ok<bool, RecoverBullFailure>>());
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

      expect(await run(), isA<Ok<bool, RecoverBullFailure>>());
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

  test('keeps the total connection phase within the global budget', () async {
    var elapsed = Duration.zero;
    final timeouts = <Duration>[];
    final bounded = ConnectToKeyServerUsecase(
      check: checkConnection,
      ensureTor: ensureSession,
      log: log,
      elapsed: () => elapsed,
      checkWithTimeout: ({required route, required timeout}) async {
        timeouts.add(timeout);
        elapsed += timeout;
        return const Ok(false);
      },
    );

    expect(
      await bounded.execute(onAttempt: attempts.add),
      isA<Ok<bool, RecoverBullFailure>>(),
    );
    expect(attempts, [1]);
    expect(timeouts, [ConnectToKeyServerUsecase.connectionBudget]);
  });

  test('does not charge a cold Tor bootstrap to the server budget', () async {
    var elapsed = Duration.zero;
    var checks = 0;
    var timeoutCalls = 0;
    final bounded = ConnectToKeyServerUsecase(
      check: checkConnection,
      ensureTor: ensureSession,
      log: log,
      elapsed: () => elapsed,
      timeout: <T>(future, timeout) {
        timeoutCalls++;
        return future;
      },
    );
    when(() => checkConnection.execute(route: route)).thenAnswer((_) async {
      checks++;
      elapsed += const Duration(seconds: 5);
      return const Ok(true);
    });
    when(() => ensureSession.execute()).thenAnswer((_) async {
      elapsed += const Duration(seconds: 37);
      return Ok(route);
    });

    final result = await bounded.execute(onAttempt: attempts.add);
    expect(result, isA<Ok<bool, RecoverBullFailure>>());
    expect((result as Ok<bool, RecoverBullFailure>).value, isTrue);
    expect(checks, 1);
    expect(timeoutCalls, 1);
  });

  test('allows a late first success inside the global budget', () async {
    var elapsed = Duration.zero;
    Duration? receivedTimeout;
    final bounded = ConnectToKeyServerUsecase(
      check: checkConnection,
      ensureTor: ensureSession,
      log: log,
      elapsed: () => elapsed,
      checkWithTimeout: ({required route, required Duration timeout}) async {
        receivedTimeout = timeout;
        elapsed += const Duration(seconds: 29);
        return const Ok(true);
      },
    );

    expect(
      await bounded.execute(onAttempt: attempts.add),
      isA<Ok<bool, RecoverBullFailure>>(),
    );
    expect(receivedTimeout, const Duration(seconds: 30));
  });

  test('gives a retry only the remaining connection budget', () async {
    var elapsed = Duration.zero;
    final timeouts = <Duration>[];
    final bounded = ConnectToKeyServerUsecase(
      check: checkConnection,
      ensureTor: ensureSession,
      log: log,
      elapsed: () => elapsed,
      wait: (duration) async => elapsed += duration,
      checkWithTimeout: ({required route, required timeout}) async {
        timeouts.add(timeout);
        elapsed += const Duration(seconds: 10);
        return const Ok(false);
      },
      budget: const Duration(seconds: 25),
    );

    await bounded.execute(onAttempt: attempts.add);

    expect(timeouts, const [
      Duration(seconds: 25),
      Duration(seconds: 14),
      Duration(seconds: 2),
    ]);
  });

  test('does not start a retry after backoff consumes the budget', () async {
    var elapsed = Duration.zero;
    var checks = 0;
    final bounded = ConnectToKeyServerUsecase(
      check: checkConnection,
      ensureTor: ensureSession,
      log: log,
      elapsed: () => elapsed,
      wait: (duration) async => elapsed += duration,
      checkWithTimeout: ({required route, required timeout}) async {
        checks++;
        elapsed += const Duration(seconds: 2);
        return const Ok(false);
      },
      budget: const Duration(seconds: 3),
    );

    await bounded.execute(onAttempt: attempts.add);

    expect(checks, 1);
    expect(attempts, [1]);
    expect(
      log.entries.map((entry) => entry.message),
      contains('recoverbull.server_check.budget_exhausted'),
    );
  });

  test('does not retry an unavailable external proxy', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Err(ExternalTorProxyUnavailableFailure()));

    final result = await usecase.execute(onAttempt: attempts.add);

    expect(result, isA<Err<bool, RecoverBullFailure>>());
    expect(attempts, [1]);
    expect(waited, isEmpty);
    expect(closeCount, 1);
  });

  test('does not retry a health timeout on the same client', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Err(KeyServerHealthCheckTimeoutFailure()));

    final result = await run();

    expect(result, isA<Err<bool, RecoverBullFailure>>());
    expect(attempts, [1]);
    verify(() => checkConnection.execute(route: route)).called(1);
    expect(waited, isEmpty);
  });

  test('retries checker failures, then closes the route', () async {
    when(() => checkConnection.execute(route: route)).thenAnswer(
      (_) async => const Err(KeyServerUnavailableFailure('timeout')),
    );

    final result = await run();

    expect(result, isA<Ok<bool, RecoverBullFailure>>());
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

      expect(result, isA<Err<bool, RecoverBullFailure>>());
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
    }, HttpClient());
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(route));
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    final future = run();
    await Future<void>.delayed(Duration.zero);
    expect(closeStarted, isTrue);
    releaseClose = true;

    expect(await future, isA<Ok<bool, RecoverBullFailure>>());
  });
}
