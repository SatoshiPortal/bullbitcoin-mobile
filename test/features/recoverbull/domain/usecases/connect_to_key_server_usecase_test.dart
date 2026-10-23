import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/connect_to_key_server_usecase.dart';
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
    usecase = ConnectToKeyServerUsecase(checkConnection, ensureSession);
  });

  test('succeeds on an answer and closes the route it acquired', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    expect(await usecase.execute(), isA<Ok<void, RecoverBullCoreFailure>>());
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

    final result = await usecase.execute();

    expect(
      (result as Err<void, RecoverBullCoreFailure>).failure,
      isA<KeyServerUnavailableFailure>().having(
        (f) => f.cause,
        'cause',
        KeyServerUnreachableCause.onionUnreachable,
      ),
    );
    verify(() => checkConnection.execute(route: route)).called(1);
    expect(closeCount, 1);
  });

  test('stops before checking when no session can be opened', () async {
    when(
      () => ensureSession.execute(),
    ).thenAnswer((_) async => const Err(ExternalTorProxyUnavailableFailure()));

    final result = await usecase.execute();

    expect(result, isA<Err<void, RecoverBullCoreFailure>>());
    verifyNever(() => checkConnection.execute(route: any(named: 'route')));
    expect(closeCount, 0);
  });

  test('a close error does not mask success', () async {
    route = RecoverBullTorRoute(
      route.route,
      () async => throw Exception('close failed'),
    );
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(route));
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    expect(await usecase.execute(), isA<Ok<void, RecoverBullCoreFailure>>());
  });

  test('borrows a supplied route without reacquiring or closing it', () async {
    when(
      () => checkConnection.execute(route: route),
    ).thenAnswer((_) async => const Ok(true));

    final result = await usecase.execute(route: route);

    expect(result, isA<Ok<void, RecoverBullCoreFailure>>());
    verifyNever(() => ensureSession.execute());
    expect(closeCount, 0);
  });
}
