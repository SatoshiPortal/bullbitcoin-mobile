import 'dart:io';
import '../../support/log_sink.dart';
import 'package:bull_recoverbull/src/domain/usecases/check_server_connection_usecase.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_recoverbull/src/domain/usecases/connect_to_key_server_usecase.dart';
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
  late ConnectToKeyServerUsecase usecase;

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
    usecase = ConnectToKeyServerUsecase(
      check: checkConnection,
      ensureTor: ensureSession,
      log: const TestLogSink(),
    );
  });

  test('succeeds on an answer and closes the route it acquired', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    expect(
      await usecase.execute(onAttempt: (_) {}),
      isA<Ok<bool, RecoverBullFailure>>(),
    );
    verify(() => checkConnection.execute(route: route)).called(1);
    expect(closeCount, 1);
  });

  test('makes a single attempt and returns its cause', () async {
    when(() => checkConnection.execute(route: route)).thenAnswer(
      (_) async => const Err(
        KeyServerUnavailableFailure.because(
          KeyServerUnreachableCause.onionUnreachable,
        ),
      ),
    );

    final result = await usecase.execute(onAttempt: (_) {});

    verify(() => checkConnection.execute(route: route)).called(1);
    expect(
      (result as Err<bool, RecoverBullFailure>).failure,
      isA<KeyServerUnavailableFailure>().having(
        (f) => f.cause,
        'cause',
        KeyServerUnreachableCause.onionUnreachable,
      ),
    );
    expect(closeCount, 1);
  });

  test('stops before checking when no session can be opened', () async {
    when(
      () => ensureSession.execute(),
    ).thenAnswer((_) async => const Err(ExternalTorProxyUnavailableFailure()));

    final result = await usecase.execute(onAttempt: (_) {});

    expect(result, isA<Err<bool, RecoverBullFailure>>());
    verifyNever(() => checkConnection.execute(route: any(named: 'route')));
    expect(closeCount, 0);
  });

  test('a close error does not mask success', () async {
    route = RecoverBullTorRoute(
      route.route,
      () async => throw Exception('close failed'),
      HttpClient(),
    );
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(route));
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    expect(
      await usecase.execute(onAttempt: (_) {}),
      isA<Ok<bool, RecoverBullFailure>>(),
    );
  });

  test('borrows a supplied route without reacquiring or closing it', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    final result = await usecase.execute(route: route, onAttempt: (_) {});

    expect(result, isA<Ok<bool, RecoverBullFailure>>());
    verifyNever(() => ensureSession.execute());
    expect(closeCount, 0);
  });
  test('preserves temporary pressure without another attempt', () async {
    when(() => checkConnection.execute(route: route)).thenAnswer(
      (_) async => const Err(
        RecoverBullTemporarilyUnavailableFailure(
          retryIn: Duration(seconds: 30),
        ),
      ),
    );
    final result = await usecase.execute(onAttempt: (_) {});
    expect(
      result,
      isA<Err<bool, RecoverBullFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<RecoverBullTemporarilyUnavailableFailure>(),
      ),
    );
    verify(() => checkConnection.execute(route: route)).called(1);
    expect(closeCount, 1);
  });

  test(
    'publishes one attempt before the check and never retries a false answer',
    () async {
      final attempts = <int>[];
      when(() => checkConnection.execute(route: route)).thenAnswer((_) async {
        expect(attempts, [1]);
        return const Ok(false);
      });
      final result = await usecase.execute(onAttempt: attempts.add);
      expect(result, isA<Err<bool, RecoverBullFailure>>());
      verify(() => checkConnection.execute(route: route)).called(1);
      expect(attempts, [1]);
    },
  );
}
