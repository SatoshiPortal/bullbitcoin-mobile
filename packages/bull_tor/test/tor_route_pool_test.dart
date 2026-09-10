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
      final events = <TorRoutePoolEvent>[];
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
        onEvent: events.add,
      );
      final second = pool.acquire(
        key: 'embedded',
        open: open,
        close: () async => closes++,
        onEvent: events.add,
      );
      gate.complete(_route(TorSource.embedded));
      final leases = await Future.wait([first, second]);

      expect(acquisitions, 1);
      expect(events, hasLength(2));
      expect(
        events.where((event) => event.type == TorRoutePoolEventType.opened),
        hasLength(1),
      );
      expect(
        events.where((event) => event.type == TorRoutePoolEventType.attached),
        hasLength(1),
      );
      expect(events.map((event) => event.holders), containsAll([1, 2]));
      await leases[0].release();
      expect(closes, 0);
      await leases[1].release();
      expect(closes, 1);
      expect(events, hasLength(3));
      expect(
        events
            .singleWhere((event) => event.type == TorRoutePoolEventType.closed)
            .holders,
        0,
      );
    },
  );

  test('external and embedded sources never share a route', () async {
    final pool = TorRoutePool();
    final events = <TorRoutePoolEvent>[];
    var acquisitions = 0;
    final embedded = await pool.acquire(
      key: 'embedded',
      open: () async {
        acquisitions++;
        return _route(TorSource.embedded);
      },
      close: () async {},
      onEvent: events.add,
    );
    final external = await pool.acquire(
      key: 'external:127.0.0.1:9050',
      open: () async {
        acquisitions++;
        return _route(TorSource.external);
      },
      close: () async {},
      onEvent: events.add,
    );

    expect(acquisitions, 2);
    expect(embedded.route.source, TorSource.embedded);
    expect(external.route.source, TorSource.external);
    expect(
      events.where((event) => event.type == TorRoutePoolEventType.opened),
      hasLength(2),
    );
    expect(
      events.map((event) => event.source),
      containsAll([TorSource.embedded, TorSource.external]),
    );
    expect(
      events
          .where((event) => event.type == TorRoutePoolEventType.opened)
          .map((event) => event.logMessage),
      containsAll([
        'recoverbull.tor.route.opened source=embedded holders=1',
        'recoverbull.tor.route.opened source=external holders=1',
      ]),
    );
    await embedded.release();
    await external.release();
  });

  test(
    'does not open a new generation before the previous close completes',
    () async {
      final pool = TorRoutePool();
      final closeStarted = Completer<void>();
      final allowClose = Completer<void>();
      var opens = 0;
      var closes = 0;
      final first = await pool.acquire(
        key: 'embedded',
        open: () async {
          opens++;
          return _route(TorSource.embedded);
        },
        close: () async {
          closes++;
          closeStarted.complete();
          await allowClose.future;
        },
      );
      final release = first.release();
      await closeStarted.future;
      final next = pool.acquire(
        key: 'embedded',
        open: () async {
          opens++;
          return _route(TorSource.embedded);
        },
        close: () async => closes++,
      );

      expect(opens, 1);
      allowClose.complete();
      await release;
      await next;
      expect(opens, 2);
      expect(closes, 1);
    },
  );

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
