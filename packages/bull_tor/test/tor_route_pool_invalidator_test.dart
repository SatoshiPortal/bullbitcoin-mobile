import 'dart:async';

import 'package:bull_tor/tor.dart';
import 'package:test/test.dart';

TorRoute _route(TorSource source, TorTransport transport) => TorRoute(
  source: source,
  endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 9050),
  evidence: source == TorSource.embedded
      ? TorReadinessEvidence.embeddedBootstrap
      : TorReadinessEvidence.externalSocksHandshake,
  transport: transport,
);

void main() {
  test('invalidates an embedded grace route on Tor unavailability', () async {
    final states = StreamController<TorConnectionState>.broadcast(sync: true);
    final pool = TorRoutePool();
    var opens = 0;
    var closes = 0;
    final invalidator = TorRoutePoolTorInvalidator(states.stream, pool);
    final lease = await pool.acquire(
      key: 'embedded',
      open: () async {
        opens++;
        return _route(TorSource.embedded, TorTransport.direct);
      },
      close: () async => closes++,
    );
    await lease.release();

    states.add(
      const TorUnavailable(
        source: TorSource.embedded,
        failure: TorUnexpectedFailure('offline'),
      ),
    );
    await invalidator.flush();

    final replacement = await pool.acquire(
      key: 'embedded',
      open: () async {
        opens++;
        return _route(TorSource.embedded, TorTransport.direct);
      },
      close: () async => closes++,
    );
    expect(opens, 2);
    expect(closes, 1);
    await replacement.release();
    await invalidator.close();
    await states.close();
    await pool.close();
  });

  test('invalidates on transport change but not directory refresh', () async {
    final states = StreamController<TorConnectionState>.broadcast(sync: true);
    final pool = TorRoutePool();
    var opens = 0;
    var closes = 0;
    final invalidator = TorRoutePoolTorInvalidator(states.stream, pool);
    Future<TorRouteLease> acquire() => pool.acquire(
      key: 'embedded',
      open: () async {
        opens++;
        return _route(TorSource.embedded, TorTransport.direct);
      },
      close: () async => closes++,
    );
    states.add(TorReady(_route(TorSource.embedded, TorTransport.direct)));
    final first = await acquire();
    await first.release();
    states.add(
      TorConnecting(source: TorSource.embedded, transport: TorTransport.direct),
    );
    await invalidator.flush();
    expect(closes, 0);
    final reused = await acquire();
    await reused.release();

    states.add(
      TorConnecting(
        source: TorSource.embedded,
        transport: TorTransport.snowflake,
      ),
    );
    await invalidator.flush();
    final changed = await acquire();
    expect(opens, 2);
    expect(closes, 1);
    await changed.release();
    await invalidator.close();
    await states.close();
    await pool.close();
  });

  test('embedded invalidation leaves external routes untouched', () async {
    final states = StreamController<TorConnectionState>.broadcast(sync: true);
    final pool = TorRoutePool();
    var externalCloses = 0;
    final invalidator = TorRoutePoolTorInvalidator(states.stream, pool);
    final external = await pool.acquire(
      key: 'external:127.0.0.1:9050',
      open: () async => _route(TorSource.external, TorTransport.direct),
      close: () async => externalCloses++,
    );
    await external.release();
    states.add(const TorStopped(TorSource.embedded));
    await invalidator.flush();
    expect(externalCloses, 0);
    final same = await pool.acquire(
      key: 'external:127.0.0.1:9050',
      open: () async => _route(TorSource.external, TorTransport.direct),
      close: () async => externalCloses++,
    );
    expect(same.route.source, TorSource.external);
    await same.release();
    await invalidator.close();
    await states.close();
    await pool.close();
  });

  test(
    'external Tor unavailability leaves embedded routes untouched',
    () async {
      final states = StreamController<TorConnectionState>.broadcast(sync: true);
      final pool = TorRoutePool();
      var closes = 0;
      final invalidator = TorRoutePoolTorInvalidator(states.stream, pool);
      final embedded = await pool.acquire(
        key: 'embedded',
        open: () async => _route(TorSource.embedded, TorTransport.direct),
        close: () async => closes++,
      );
      await embedded.release();

      states.add(
        const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        ),
      );
      await invalidator.flush();

      expect(closes, 0);
      final same = await pool.acquire(
        key: 'embedded',
        open: () async => _route(TorSource.embedded, TorTransport.direct),
        close: () async => closes++,
      );
      expect(same.route.source, TorSource.embedded);
      await same.release();
      await invalidator.close();
      await states.close();
      await pool.close();
    },
  );
}
