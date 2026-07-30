import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tor/tor.dart';

class _MockEmbeddedTor extends Mock implements EmbeddedTor {}

class _MockTorSessions extends Mock implements TorSessions {}

void main() {
  late _MockEmbeddedTor embeddedTor;
  late _MockTorSessions sessions;
  late EnsureRecoverBullTorSessionUsecase usecase;

  setUp(() {
    embeddedTor = _MockEmbeddedTor();
    sessions = _MockTorSessions();
    when(() => embeddedTor.sessions).thenReturn(sessions);
    usecase = EnsureRecoverBullTorSessionUsecase(embeddedTor);
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

    expect(result, isA<Ok<TorSession, RecoverBullCoreFailure>>());
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

    expect(result, isA<Err<TorSession, RecoverBullCoreFailure>>());
    verifyNever(() => sessions.open());
  });
}
