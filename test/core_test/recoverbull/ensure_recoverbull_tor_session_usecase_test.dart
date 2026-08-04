import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEmbeddedTor extends Mock implements EmbeddedTor {}

class _MockTorSessions extends Mock implements TorSessions {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

SettingsEntity _settings({bool useTorProxy = false, int torProxyPort = 9050}) =>
    SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.btc,
      currencyCode: 'CAD',
      useTorProxy: useTorProxy,
      torProxyPort: torProxyPort,
    );

void main() {
  late _MockEmbeddedTor embeddedTor;
  late _MockTorSessions sessions;
  late _MockSettingsRepository settingsRepository;
  late EnsureRecoverBullTorSessionUsecase usecase;

  setUp(() {
    embeddedTor = _MockEmbeddedTor();
    sessions = _MockTorSessions();
    settingsRepository = _MockSettingsRepository();
    when(() => embeddedTor.sessions).thenReturn(sessions);
    when(() => settingsRepository.fetch()).thenAnswer((_) async => _settings());
    usecase = EnsureRecoverBullTorSessionUsecase(
      embeddedTor,
      settingsRepository,
    );
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

  // Embedded Tor cannot bootstrap inside Orbot's device-wide tunnel, so an
  // Orbot user has to reach the key server through Orbot's own SOCKS port.
  // Loopback is what makes that work: it never traverses the tun interface.
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
}
