import 'package:bull_sdk/onion.dart' as onion;
import 'package:bull_tor/src/data/onion_tor_backend.dart';
import 'package:bull_tor/src/domain/ports/embedded_tor_port.dart';
import 'package:bull_tor/tor.dart';
import 'package:test/test.dart';

void main() {
  final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41001);

  onion.TorStatus blocked(onion.BlockageKind kind, String message) =>
      onion.TorStatus(
        fraction: 0.4,
        readyForTraffic: false,
        blockage: onion.Blockage(kind: kind, message: message),
        transport: onion.TorTransport.direct,
      );

  group('OnionTorBackend.eventFor', () {
    test('keeps arti\'s blockage message as the bootstrap detail', () {
      final event = OnionTorBackend.eventFor(
        blocked(onion.BlockageKind.clockSkewed, 'Clock is skewed by 2 hours'),
        endpoint,
      );

      expect(event, isA<EmbeddedTorConnecting>());
      final connecting = event as EmbeddedTorConnecting;
      expect(connecting.diagnostic, TorDiagnostic.clockSkewed);
      expect(connecting.detail?.blockage, 'Clock is skewed by 2 hours');
      expect(connecting.detail?.stage, isNull);
    });

    // `notStarted` is arti describing our own manual bootstrap back to us.
    test('drops the message of a blockage that is not a fault', () {
      final event = OnionTorBackend.eventFor(
        blocked(
          onion.BlockageKind.notStarted,
          'Client is waiting to be told to bootstrap',
        ),
        endpoint,
      );

      expect((event as EmbeddedTorConnecting).detail, isNull);
    });

    test('carries no detail when arti reports no blockage', () {
      final event = OnionTorBackend.eventFor(
        const onion.TorStatus(
          fraction: 0.4,
          readyForTraffic: false,
          transport: onion.TorTransport.direct,
        ),
        endpoint,
      );

      expect((event as EmbeddedTorConnecting).detail, isNull);
    });
  });

  test('a failed bootstrap keeps the last blockage detail', () {
    final failure = OnionTorBackend.failureFor(
      const onion.TorFailure(
        kind: onion.TorFailureKind.bootstrap,
        logMessage: 'bootstrap failed',
      ),
      TorDiagnostic.clockSkewed,
      const TorBootstrapDetail(blockage: 'Clock is skewed by 2 hours'),
    );

    expect(failure, isA<TorBootstrapFailure>());
    final bootstrap = failure as TorBootstrapFailure;
    expect(bootstrap.diagnostic, TorDiagnostic.clockSkewed);
    expect(bootstrap.detail?.blockage, 'Clock is skewed by 2 hours');
  });
}
