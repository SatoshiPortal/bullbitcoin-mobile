import 'dart:async';

import 'package:bull_tor/tor.dart';
import 'package:test/test.dart';

TorRoute _route(TorSource source) => TorRoute(
  source: source,
  endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 9050),
  evidence: source == TorSource.embedded
      ? TorReadinessEvidence.embeddedBootstrap
      : TorReadinessEvidence.externalSocksHandshake,
);

void main() {
  test(
    'concurrent consumers share one acquisition and close after the last release',
    () async {
      final pool = TorRoutePool();
      var acquisitions = 0;
      var closes = 0;
      final gate = Completer<TorRoute>();
      Future<TorRoute> open() async {
        acquisitions++;
        return gate.future;
      }

      final first = pool.acquire(
        key: 'embedded',
        open: open,
        close: () async => closes++,
      );
      final second = pool.acquire(
        key: 'embedded',
        open: open,
        close: () async => closes++,
      );
      gate.complete(_route(TorSource.embedded));
      final leases = await Future.wait([first, second]);

      expect(acquisitions, 1);
      await leases[0].release();
      expect(closes, 0);
      await leases[1].release();
      expect(closes, 1);
    },
  );

  test('external and embedded sources never share a route', () async {
    final pool = TorRoutePool();
    var acquisitions = 0;
    final embedded = await pool.acquire(
      key: 'embedded',
      open: () async {
        acquisitions++;
        return _route(TorSource.embedded);
      },
      close: () async {},
    );
    final external = await pool.acquire(
      key: 'external:127.0.0.1:9050',
      open: () async {
        acquisitions++;
        return _route(TorSource.external);
      },
      close: () async {},
    );

    expect(acquisitions, 2);
    expect(embedded.route.source, TorSource.embedded);
    expect(external.route.source, TorSource.external);
    await embedded.release();
    await external.release();
  });

  test(
    'closing one flow does not close a route still used by monitoring',
    () async {
      final pool = TorRoutePool();
      var closed = 0;
      final flow = await pool.acquire(
        key: 'embedded',
        open: () async => _route(TorSource.embedded),
        close: () async => closed++,
      );
      final monitoring = await pool.acquire(
        key: 'embedded',
        open: () async => _route(TorSource.embedded),
        close: () async => closed++,
      );

      await flow.release();
      expect(closed, 0);
      await monitoring.release();
      expect(closed, 1);
    },
  );
}
