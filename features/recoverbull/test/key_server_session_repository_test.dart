import 'package:bull_recoverbull/src/data/key_server_session_repository_impl.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_route_port.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  Future<Duration> operationTimeoutThrough(TorTransport transport) async {
    final sessions = KeyServerSessionRepositoryImpl(
      _Routes(transport),
      const TorHttpClientFactory(),
    );
    final result = await sessions.open(Uri.parse('http://server.onion'));
    final server = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('$failure'),
    };
    addTearDown(server.close);
    return server.operationTimeout;
  }

  // Tor's own budget must expire first so its reason, not a bare timeout, reaches the user.
  test('an operation outlasts the Tor connect budget of its route', () async {
    for (final transport in TorTransport.values) {
      expect(
        await operationTimeoutThrough(transport),
        greaterThan(transport.connectBudget),
      );
    }
  });

  test('Snowflake gives a key-server operation a longer budget', () async {
    expect(
      await operationTimeoutThrough(TorTransport.snowflake),
      greaterThan(await operationTimeoutThrough(TorTransport.direct)),
    );
  });
}

final class _Routes implements RecoverBullRoutePort {
  final TorTransport transport;

  _Routes(this.transport);

  @override
  Future<Result<RecoverBullRoute, RecoverBullFailure>> open({
    bool restartEmbedded = false,
    bool viaSnowflake = false,
  }) async => Ok(
    RecoverBullRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 9050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: transport,
      ),
      () async {},
    ),
  );

  @override
  bool get snowflakeAvailable => true;

  @override
  Stream<TorConnectionState> watch() => const Stream.empty();
}
