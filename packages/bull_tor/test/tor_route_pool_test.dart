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
  test('reuses a route during its grace period', () async {
    final clock = _ManualTimers();
    final pool = TorRoutePool(
      gracePeriod: const Duration(seconds: 90),
      timerFactory: clock.create,
    );
    final events = <TorRoutePoolEvent>[];
    var opens = 0;
    var closes = 0;
    final first = await pool.acquire(
      key: 'embedded',
      open: () async {
        opens++;
        return _route(TorSource.embedded);
      },
      close: () async => closes++,
      onEvent: events.add,
    );

    await first.release();
    final second = await pool.acquire(
      key: 'embedded',
      open: () async {
        opens++;
        return _route(TorSource.embedded);
      },
      close: () async => closes++,
      onEvent: events.add,
    );

    expect(opens, 1);
    expect(closes, 0);
    expect(events.last.type, TorRoutePoolEventType.attached);
    expect(events.last.holders, 1);
    await second.release();
    await pool.close();
  });

  test('expires a grace route and opens a new generation', () async {
    final clock = _ManualTimers();
    final pool = TorRoutePool(timerFactory: clock.create);
    var opens = 0;
    var closes = 0;
    Future<TorRoute> open() async {
      opens++;
      return _route(TorSource.embedded);
    }

    final first = await pool.acquire(
      key: 'embedded',
      open: open,
      close: () async => closes++,
    );
    await first.release();
    clock.elapse();
    expect(closes, 1);
    clock.elapse();
    expect(closes, 1);

    final second = await pool.acquire(
      key: 'embedded',
      open: open,
      close: () async => closes++,
    );
    expect(opens, 2);
    await second.release();
    await pool.close();
  });

  test('invalidation closes a grace route immediately', () async {
    final clock = _ManualTimers();
    final pool = TorRoutePool(timerFactory: clock.create);
    var opens = 0;
    var closes = 0;
    final lease = await pool.acquire(
      key: 'embedded',
      open: () async {
        opens++;
        return _route(TorSource.embedded);
      },
      close: () async => closes++,
    );
    await lease.release();

    await pool.invalidate(key: 'embedded');
    expect(closes, 1);
    clock.elapse();
    expect(closes, 1);
    final replacement = await pool.acquire(
      key: 'embedded',
      open: () async {
        opens++;
        return _route(TorSource.embedded);
      },
      close: () async => closes++,
    );
    expect(opens, 2);
    await replacement.release();
    await pool.close();
  });

  test('invalidation does not close an actively held route', () async {
    final pool = TorRoutePool();
    var closes = 0;
    final lease = await pool.acquire(
      key: 'embedded',
      open: () async => _route(TorSource.embedded),
      close: () async => closes++,
    );

    await pool.invalidate(key: 'embedded');

    expect(closes, 0);
    await lease.release();
    expect(closes, 1);
    await pool.close();
  });

  test('pool close cancels grace timers and closes routes', () async {
    final clock = _ManualTimers();
    final pool = TorRoutePool(timerFactory: clock.create);
    var closes = 0;
    final lease = await pool.acquire(
      key: 'embedded',
      open: () async => _route(TorSource.embedded),
      close: () async => closes++,
    );
    await lease.release();

    await pool.close();
    clock.elapse();
    expect(closes, 1);
    expect(clock.active, 0);
  });

  test(
    'pool close cleans up an acquisition that completes during shutdown',
    () async {
      final pool = TorRoutePool();
      final opened = Completer<TorRoute>();
      var closes = 0;
      final acquisition = pool.acquire(
        key: 'embedded',
        open: () => opened.future,
        close: () async => closes++,
      );

      final shutdown = pool.close();
      opened.complete(_route(TorSource.embedded));

      await expectLater(acquisition, throwsStateError);
      await shutdown;
      expect(closes, 1);
    },
  );

  test(
    'concurrent consumers share one acquisition and close after the last release',
    () async {
      final clock = _ManualTimers();
      final pool = TorRoutePool(timerFactory: clock.create);
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
      expect(closes, 0);
      clock.elapse();
      await Future<void>.delayed(Duration.zero);
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

  test(
    'reacquires when the first lease is released before a pending consumer resumes',
    () async {
      final clock = _ManualTimers();
      final pool = TorRoutePool(timerFactory: clock.create);
      final events = <TorRoutePoolEvent>[];
      final routeOpen = Completer<TorRoute>();
      var opens = 0;
      var closes = 0;

      Future<TorRoute> open() async {
        opens++;
        if (opens == 1) return routeOpen.future;
        return _route(TorSource.embedded);
      }

      final firstFuture = pool.acquire(
        key: 'embedded',
        open: open,
        close: () async => closes++,
        onEvent: events.add,
      );
      final secondFuture = pool.acquire(
        key: 'embedded',
        open: open,
        close: () async => closes++,
        onEvent: events.add,
      );
      routeOpen.complete(_route(TorSource.embedded));

      final first = await firstFuture;
      await first.release();
      final second = await secondFuture;

      expect(opens, 1);
      expect(second.route.endpoint.port, 9050);
      expect(second.route, same(first.route));
      expect(events.map((event) => event.holders), contains(1));
      expect(
        events.where((event) => event.type == TorRoutePoolEventType.attached),
        hasLength(1),
      );
      expect(
        events.where((event) => event.type == TorRoutePoolEventType.closed),
        isEmpty,
      );
      expect(closes, 0);
      await second.release();
      clock.elapse();
      await Future<void>.delayed(Duration.zero);
      expect(closes, 1);
    },
  );

  test('does not distribute an entry once its close has started', () async {
    final clock = _ManualTimers();
    final pool = TorRoutePool(
      gracePeriod: Duration.zero,
      timerFactory: clock.create,
    );
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

    final firstClose = first.release();
    clock.elapse();
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
    final nextLease = await next;
    await firstClose;
    expect(opens, 2);
    expect(closes, 1);
    expect(nextLease.route, isNot(same(first.route)));
    await nextLease.release();
  });

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
      final clock = _ManualTimers();
      final pool = TorRoutePool(
        gracePeriod: Duration.zero,
        timerFactory: clock.create,
      );
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
      clock.elapse();
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
      final clock = _ManualTimers();
      final pool = TorRoutePool(timerFactory: clock.create);
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
      clock.elapse();
      await Future<void>.delayed(Duration.zero);
      expect(closed, 1);
    },
  );
}

final class _ManualTimers {
  final List<_ManualTimer> _timers = [];

  int get active => _timers.where((timer) => !timer.cancelled).length;

  TorRoutePoolTimer create(Duration _, void Function() callback) {
    final timer = _ManualTimer(callback);
    _timers.add(timer);
    return timer;
  }

  void elapse() {
    for (final timer in List<_ManualTimer>.from(_timers)) {
      timer.fire();
    }
  }
}

final class _ManualTimer implements TorRoutePoolTimer {
  final void Function() _callback;
  bool cancelled = false;

  _ManualTimer(this._callback);

  @override
  void cancel() => cancelled = true;

  void fire() {
    if (cancelled) return;
    cancelled = true;
    _callback();
  }
}
