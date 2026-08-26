import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/ports.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEmbeddedTor extends Mock implements EmbeddedTor {}

class _MockTorSessions extends Mock implements TorSessions {}

class _MockSettingsRepository extends Mock implements RecoverBullSettingsPort {}

class _MockTor extends Mock implements Tor {}

class _MockExternalTor extends Mock implements ExternalTor {}

class _FakeExternalTorPort {
  bool available = true;

  Future<void> verify(TorProxyEndpoint endpoint) async {
    if (!available) throw StateError('proxy unavailable');
  }
}

RecoverBullTorSettings _settings({
  bool useTorProxy = false,
  int torProxyPort = 9050,
}) => RecoverBullTorSettings(
  useTorProxy: useTorProxy,
  torProxyPort: torProxyPort,
);

void main() {
  late _MockEmbeddedTor embeddedTor;
  late _MockTorSessions sessions;
  late _MockSettingsRepository settingsRepository;
  late _MockTor tor;
  late _MockExternalTor externalTor;
  late _FakeExternalTorPort externalTorPort;
  late EnsureRecoverBullTorSessionUsecase usecase;

  setUp(() {
    embeddedTor = _MockEmbeddedTor();
    sessions = _MockTorSessions();
    settingsRepository = _MockSettingsRepository();
    tor = _MockTor();
    externalTor = _MockExternalTor();
    externalTorPort = _FakeExternalTorPort();
    when(() => embeddedTor.sessions).thenReturn(sessions);
    when(() => settingsRepository.fetch()).thenAnswer((_) async => _settings());
    when(() => tor.external).thenReturn(externalTor);
    when(() => externalTor.verify(any())).thenAnswer((invocation) async {
      final endpoint =
          invocation.positionalArguments.single as TorProxyEndpoint;
      if (!externalTorPort.available) {
        return const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        );
      }
      return TorReady(
        TorRoute(
          source: TorSource.external,
          endpoint: endpoint,
          evidence: TorReadinessEvidence.externalSocksHandshake,
        ),
      );
    });
    usecase = EnsureRecoverBullTorSessionUsecase(
      embeddedTor,
      settingsRepository,
      tor,
    );
  });

  setUpAll(() {
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 9050));
  });

  test('accepts an embedded Onion route', () async {
    final route = TorRoute(
      source: TorSource.embedded,
      endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
      evidence: TorReadinessEvidence.embeddedBootstrap,
      transport: TorTransport.direct,
    );
    final session = TorSession(
      TorProxyEndpoint(host: '127.0.0.1', port: 19051),
      TorTransport.direct,
      () async {},
    );
    when(
      () => embeddedTor.ensureReady(),
    ).thenAnswer((_) async => TorReady(route));
    when(() => sessions.open()).thenAnswer((_) async => session);

    final result = await usecase.execute();

    expect(result, isA<Ok<RecoverBullTorRoute, RecoverBullCoreFailure>>());
  });

  test('rejects an external SOCKS route', () async {
    final route = TorRoute(
      source: TorSource.external,
      endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 9050),
      evidence: TorReadinessEvidence.externalSocksHandshake,
    );
    when(
      () => embeddedTor.ensureReady(),
    ).thenAnswer((_) async => TorReady(route));

    final result = await usecase.execute();

    expect(result, isA<Err<RecoverBullTorRoute, RecoverBullCoreFailure>>());
    verifyNever(() => sessions.open());
  });

  // A user-managed proxy is borrowed through its loopback SOCKS5 endpoint; the app must neither bootstrap embedded Tor nor assume ownership of that proxy.
  test('routes through the external proxy when the user enabled it', () async {
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(useTorProxy: true, torProxyPort: 9050));

    final result = await usecase.execute();

    expect(result, isA<Ok<RecoverBullTorRoute, RecoverBullCoreFailure>>());
    final route =
        (result as Ok<RecoverBullTorRoute, RecoverBullCoreFailure>).value;
    expect(route.endpoint.host, '127.0.0.1');
    expect(route.endpoint.port, 9050);
    verifyNever(() => embeddedTor.ensureReady());
    verifyNever(() => sessions.open());
    // Closing must not tear down a proxy the app does not own.
    await route.close();
  });

  test('honours a custom external proxy port', () async {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => _settings(useTorProxy: true, torProxyPort: 19050),
    );

    final result = await usecase.execute();

    final route =
        (result as Ok<RecoverBullTorRoute, RecoverBullCoreFailure>).value;
    expect(route.endpoint.port, 19050);
  });

  test('fails closed for an invalid external proxy port', () async {
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(useTorProxy: true, torProxyPort: 0));

    final result = await usecase.execute();

    expect(result, isA<Err<RecoverBullTorRoute, RecoverBullCoreFailure>>());
    verifyNever(() => externalTor.verify(any()));
    verifyNever(() => embeddedTor.ensureReady());
  });

  test(
    'rejects an unavailable external proxy before opening any session',
    () async {
      externalTorPort.available = false;
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => _settings(useTorProxy: true, torProxyPort: 9050),
      );

      final result = await usecase.execute();

      expect(result, isA<Err<RecoverBullTorRoute, RecoverBullCoreFailure>>());
      expect(
        (result as Err<RecoverBullTorRoute, RecoverBullCoreFailure>).failure,
        isA<ExternalTorProxyUnavailableFailure>(),
      );
      verifyNever(() => embeddedTor.ensureReady());
      verifyNever(() => sessions.open());
    },
  );

  test(
    'reports failed timing when the external proxy is unavailable',
    () async {
      final timings = <({String phase, int duration, String outcome})>[];
      externalTorPort.available = false;
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _settings(useTorProxy: true));
      usecase = EnsureRecoverBullTorSessionUsecase(
        embeddedTor,
        settingsRepository,
        tor,
        timing: (phase, duration, outcome) =>
            timings.add((phase: phase, duration: duration, outcome: outcome)),
      );

      await usecase.execute();

      expect(timings, hasLength(1));
      expect(timings.single.phase, 'tor_route_acquire');
      expect(timings.single.outcome, 'failure');
    },
  );

  test('rechecks external proxy instead of restarting embedded Tor', () async {
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(useTorProxy: true));

    final result = await usecase.execute(restartEmbedded: true);

    expect(result, isA<Ok<RecoverBullTorRoute, RecoverBullCoreFailure>>());
    verifyNever(() => embeddedTor.ensureReady());
    verifyNever(() => embeddedTor.retry());
  });

  test('maps settings fetch exceptions to a failure result', () async {
    when(
      () => settingsRepository.fetch(),
    ).thenThrow(Exception('settings down'));

    final result = await usecase.execute();

    expect(result, isA<Err<RecoverBullTorRoute, RecoverBullCoreFailure>>());
    expect(
      (result as Err<RecoverBullTorRoute, RecoverBullCoreFailure>).failure,
      isA<KeyServerUnavailableFailure>(),
    );
  });

  test('maps Tor ensureReady exceptions to a failure result', () async {
    when(() => embeddedTor.ensureReady()).thenThrow(
      const TorBackendException(TorBootstrapFailure('bootstrap failed')),
    );

    final result = await usecase.execute();

    expect(result, isA<Err<RecoverBullTorRoute, RecoverBullCoreFailure>>());
    expect(
      (result as Err<RecoverBullTorRoute, RecoverBullCoreFailure>).failure,
      isA<KeyServerUnavailableFailure>(),
    );
  });

  test(
    'closes an embedded session when HTTP client construction fails',
    () async {
      var sessionClosed = false;
      final session = TorSession(
        TorProxyEndpoint(host: 'not-an-ip-literal', port: 19051),
        TorTransport.direct,
        () async => sessionClosed = true,
      );
      when(() => embeddedTor.ensureReady()).thenAnswer(
        (_) async => TorReady(
          TorRoute(
            source: TorSource.embedded,
            endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
            evidence: TorReadinessEvidence.embeddedBootstrap,
          ),
        ),
      );
      when(() => sessions.open()).thenAnswer((_) async => session);

      final result = await usecase.execute();

      expect(result, isA<Err<RecoverBullTorRoute, RecoverBullCoreFailure>>());
      expect(sessionClosed, isTrue);
    },
  );
}
