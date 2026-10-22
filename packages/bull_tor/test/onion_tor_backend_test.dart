import 'package:bull_sdk/onion.dart' as onion;
import 'package:bull_tor/src/data/onion_tor_backend.dart';
import 'package:bull_tor/src/data/tor_logger.dart';
import 'package:bull_tor/src/domain/entities/tor_proxy_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 9050);

  onion.TorStatus status(double fraction, {bool ready = false}) =>
      onion.TorStatus(
        fraction: fraction,
        readyForTraffic: ready,
        stage: '',
        transport: onion.TorTransport.direct,
      );

  test('logs each readiness change once, including regressions', () {
    final lines = <Object?>[];
    final backend = OnionTorBackend(
      TorLogger(fineCallback: (message, {error, trace}) => lines.add(message)),
    );

    for (final s in [
      status(0),
      status(0.001),
      status(0.85),
      status(0.85),
      status(1, ready: true),
      status(0.45),
      status(1, ready: true),
      status(1, ready: true),
      status(1, ready: true),
    ]) {
      backend.handleStatus(s, endpoint);
    }

    expect(lines, [
      'Embedded Tor readiness waiting (0%)',
      'Embedded Tor readiness waiting (85%)',
      'Embedded Tor readiness ready (100%)',
      'Embedded Tor readiness waiting (45%)',
      'Embedded Tor readiness ready (100%)',
    ]);
  });
}
