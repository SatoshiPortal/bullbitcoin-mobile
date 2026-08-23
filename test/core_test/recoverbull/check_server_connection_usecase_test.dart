import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
    );
  });

  setUpAll(() => registerFallbackValue(endpoint));

  setUp(() {
    repository = _MockRepository();
    ensureSession = _MockEnsureSession();
    usecase = CheckServerConnectionUsecase(repository, ensureSession);
  });

  test('reachable server over the embedded route -> true', () async {
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(session));
    when(() => repository.checkConnection(any())).thenAnswer((_) async {});

    expect(await usecase.execute(), isA<Ok<bool, RecoverBullCoreFailure>>());
    verify(() => repository.checkConnection(endpoint)).called(1);
    expect(sessionClosed, isTrue);
  });

  test('no Tor route -> false, server never contacted', () async {
    when(() => ensureSession.execute()).thenAnswer(
      (_) async => const Err(KeyServerUnavailableFailure('tor down')),
    );

    expect(await usecase.execute(), isA<Err<bool, RecoverBullCoreFailure>>());
    verifyNever(() => repository.checkConnection(any()));
  });

  test(
    'external proxy failure is typed and never contacts the server',
    () async {
      when(() => ensureSession.execute()).thenAnswer(
        (_) async => const Err(ExternalTorProxyUnavailableFailure()),
      );

      final result = await usecase.execute();

      expect(result, isA<Err<bool, RecoverBullCoreFailure>>());
      expect(
        (result as Err<bool, RecoverBullCoreFailure>).failure,
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

    expect(await usecase.execute(), isA<Err<bool, RecoverBullCoreFailure>>());
    expect(sessionClosed, isTrue);
  });

  test('server that rejects asynchronously -> false', () async {
    when(() => ensureSession.execute()).thenAnswer((_) async => Ok(session));
    when(
      () => repository.checkConnection(any()),
    ).thenAnswer((_) async => throw Exception('timeout'));

    expect(await usecase.execute(), isA<Err<bool, RecoverBullCoreFailure>>());
    expect(sessionClosed, isTrue);
  });
}
