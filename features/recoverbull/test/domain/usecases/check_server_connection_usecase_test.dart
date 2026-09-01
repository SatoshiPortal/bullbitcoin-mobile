import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/check_server_connection_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/log_sink.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:io';

import 'package:bull_tor/tor.dart';

class _MockRepository extends Mock implements RecoverBullRepository {}

class _MockEnsureSession extends Mock
    implements EnsureRecoverBullTorSessionUsecase {}

void main() {
  late _MockRepository repository;
  late _MockEnsureSession ensureSession;
  late CheckServerConnectionUsecase usecase;

  final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 19050);
  var sessionClosed = false;
  late RecoverBullTorRoute session;

  setUp(() {
    sessionClosed = false;
    session = RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: endpoint,
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.direct,
      ),
      () async => sessionClosed = true,
      HttpClient(),
    );
  });

  setUpAll(
    () => registerFallbackValue(
      RecoverBullTorRoute(
        TorRoute(
          source: TorSource.embedded,
          endpoint: endpoint,
          evidence: TorReadinessEvidence.embeddedBootstrap,
        ),
        () async {},
        HttpClient(),
      ),
    ),
  );

  setUp(() {
    repository = _MockRepository();
    ensureSession = _MockEnsureSession();
    usecase = CheckServerConnectionUsecase(
      repository: repository,
      ensureTor: ensureSession,
      log: const TestLogSink(),
    );
  });

  test('reachable server over the embedded route -> true', () async {
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(session));
    when(() => repository.checkConnection(any())).thenAnswer((_) async {});

    expect(await usecase.execute(), isA<Ok<bool, RecoverBullFailure>>());
    verify(() => repository.checkConnection(session)).called(1);
    expect(sessionClosed, isTrue);
  });

  test('no Tor route -> false, server never contacted', () async {
    when(() => ensureSession.execute()).thenAnswer(
      (_) async => const Err(KeyServerUnavailableFailure('tor down')),
    );

    expect(await usecase.execute(), isA<Err<bool, RecoverBullFailure>>());
    verifyNever(() => repository.checkConnection(any()));
  });

  test(
    'external proxy failure is typed and never contacts the server',
    () async {
      when(() => ensureSession.execute()).thenAnswer(
        (_) async => const Err(ExternalTorProxyUnavailableFailure()),
      );

      final result = await usecase.execute();

      expect(result, isA<Err<bool, RecoverBullFailure>>());
      expect(
        (result as Err<bool, RecoverBullFailure>).failure,
        isA<ExternalTorProxyUnavailableFailure>(),
      );
      verifyNever(() => repository.checkConnection(any()));
    },
  );

  // Regression pin: the check used to return the repository call as a future
  // from inside its `try`, which chained the throw outside the block — the
  // caller got an exception instead of `false`, aborting its retry loop.
  test('throwing server check -> false, never rethrown', () async {
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(session));
    when(
      () => repository.checkConnection(any()),
    ).thenThrow(Exception('key server unreachable'));

    expect(await usecase.execute(), isA<Err<bool, RecoverBullFailure>>());
    expect(sessionClosed, isTrue);
  });

  test('does not expose raw server exception details in the failure', () async {
    const rawMessage = 'socket reset at 10.0.0.7:9050';
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(session));
    when(
      () => repository.checkConnection(any()),
    ).thenThrow(Exception(rawMessage));

    final result = await usecase.execute();

    final failure = (result as Err<bool, RecoverBullFailure>).failure;
    expect(failure, isA<KeyServerUnavailableFailure>());
    expect(failure.logMessage, isNot(contains(rawMessage)));
  });

  test('server that rejects asynchronously -> false', () async {
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(session));
    when(
      () => repository.checkConnection(any()),
    ).thenAnswer((_) async => throw Exception('timeout'));

    expect(await usecase.execute(), isA<Err<bool, RecoverBullFailure>>());
    expect(sessionClosed, isTrue);
  });

  test('provided route is used without acquiring or closing it', () async {
    when(() => repository.checkConnection(session)).thenAnswer((_) async {});

    final result = await usecase.execute(route: session);

    expect(result, isA<Ok<bool, RecoverBullFailure>>());
    verifyNever(() => ensureSession.execute());
    expect(sessionClosed, isFalse);
  });

  test('provided route remains open when the repository fails', () async {
    when(
      () => repository.checkConnection(session),
    ).thenThrow(Exception('server unavailable'));

    final result = await usecase.execute(route: session);

    expect(result, isA<Err<bool, RecoverBullFailure>>());
    verifyNever(() => ensureSession.execute());
    expect(sessionClosed, isFalse);
  });

  test('a close failure does not replace a successful owned check', () async {
    session = RecoverBullTorRoute(
      session.route,
      () async => throw Exception('close failed'),
      HttpClient(),
    );
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(session));
    when(() => repository.checkConnection(session)).thenAnswer((_) async {});

    expect(await usecase.execute(), isA<Ok<bool, RecoverBullFailure>>());
  });
}
