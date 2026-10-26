import 'dart:async';
import 'dart:io';

import 'package:bull_sdk/onion.dart' as onion;
import 'package:bull_tor/src/data/onion_tor_backend.dart';
import 'package:bull_tor/src/data/onion_client_launcher.dart';
import 'package:bull_tor/src/data/tor_logger.dart';
import 'package:bull_tor/src/domain/entities/tor_proxy_endpoint.dart';
import 'package:bull_tor/src/domain/entities/tor_transport.dart';
import 'package:bull_tor/src/domain/ports/embedded_tor_port.dart';
import 'package:bull_tor/src/domain/tor_failure.dart';
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

  group('waitForTraffic', () {
    test('waits past a usable directory until Arti is ready', () async {
      final backend = OnionTorBackend(const TorLogger());
      var ready = false;
      final waiting = backend
          .waitForTraffic(const Duration(seconds: 5))
          .then((_) => ready = true);

      backend.handleStatus(status(0.85), endpoint);
      await Future<void>.delayed(Duration.zero);
      expect(ready, isFalse);

      backend.handleStatus(status(1, ready: true), endpoint);
      await waiting;
      expect(ready, isTrue);
    });

    test('fails as a bootstrap timeout when Arti never gets ready', () {
      final backend = OnionTorBackend(const TorLogger());
      backend.handleStatus(status(0.93), endpoint);

      expect(
        backend.waitForTraffic(const Duration(milliseconds: 10)),
        throwsA(
          isA<TorBackendException>().having(
            (e) => e.failure,
            'failure',
            isA<TorBootstrapTimeoutFailure>(),
          ),
        ),
      );
    });

    test('stop releases the wait instead of holding it to the timeout', () {
      final backend = OnionTorBackend(const TorLogger());
      final waiting = backend.waitForTraffic(const Duration(minutes: 1));

      backend.stop();

      expect(waiting, throwsA(isA<TorBackendException>()));
    });
  });

  group('readiness hold', () {
    test(
      'republishes Arti readiness as full progress until the hold is served',
      () async {
        final backend = OnionTorBackend(const TorLogger());
        final events = <EmbeddedTorEvent>[];
        backend.watch().listen(events.add);

        backend.handleStatus(status(1, ready: true), endpoint);

        expect(events.single, isA<EmbeddedTorConnecting>());
        expect((events.single as EmbeddedTorConnecting).progress, 1);
      },
    );

    test('waits for the configured hold', () async {
      final waited = <Duration>[];
      final backend = OnionTorBackend(
        const TorLogger(),
        readinessHold: const Duration(seconds: 15),
        wait: (duration) async => waited.add(duration),
      );

      await backend.holdReadiness();

      expect(waited, [const Duration(seconds: 15)]);
    });

    test(
      'stop ends the hold instead of queueing a restart behind it',
      () async {
        final never = Completer<void>();
        final backend = OnionTorBackend(
          const TorLogger(),
          wait: (_) => never.future,
        );
        final holding = backend.holdReadiness();

        await backend.stop();

        await expectLater(holding, completes);
      },
    );
  });

  group('startup readiness regressions', () {
    late Directory root;
    late _ReadinessService service;
    late Completer<void> holding;
    late Completer<void> releaseHold;
    late OnionTorBackend backend;
    late List<EmbeddedTorEvent> events;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('tor_readiness_');
      service = _ReadinessService();
      holding = Completer<void>();
      releaseHold = Completer<void>();
      backend = OnionTorBackend(
        const TorLogger(),
        launcher: _ReadinessLauncher(service),
        directories: (_) async => torDirectoriesUnder(root.path),
        wait: (_) {
          holding.complete();
          return releaseHold.future;
        },
      );
      events = [];
      backend.watch().listen(events.add);
    });

    tearDown(() async {
      await backend.close();
      await service.statuses.close();
      await root.delete(recursive: true);
    });

    test(
      'waits for fresh readiness after a regression during the hold',
      () async {
        var completed = false;
        final starting = backend.start(TorTransport.direct).then((value) {
          completed = true;
          return value;
        });
        await holding.future;
        service.statuses.add(status(0.45));
        releaseHold.complete();
        await Future<void>.delayed(Duration.zero);

        expect(completed, isFalse);
        expect(events.whereType<EmbeddedTorReady>(), isEmpty);

        service.statuses.add(status(1, ready: true));
        await starting;
        expect(events.whereType<EmbeddedTorReady>(), hasLength(1));
      },
    );

    test('rechecks readiness after the awaited listener check', () async {
      final checking = Completer<void>();
      final listenerResult = Completer<bool>();
      service.checkListener = () {
        if (!checking.isCompleted) checking.complete();
        return listenerResult.future;
      };
      var completed = false;
      final starting = backend.start(TorTransport.direct).then((value) {
        completed = true;
        return value;
      });
      await holding.future;
      releaseHold.complete();
      await checking.future;
      service.statuses.add(status(0.45));
      listenerResult.complete(true);
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);
      expect(events.whereType<EmbeddedTorReady>(), isEmpty);
      service.statuses.add(status(1, ready: true));
      await starting;
      expect(events.whereType<EmbeddedTorReady>(), hasLength(1));
    });

    test(
      'stop cancels a regressed startup without announcing readiness',
      () async {
        final starting = backend.start(TorTransport.direct);
        final cancelled = expectLater(
          starting,
          throwsA(isA<TorBackendException>()),
        );
        await holding.future;
        service.statuses.add(status(0.45));
        releaseHold.complete();
        await Future<void>.delayed(Duration.zero);
        await backend.stop();
        await cancelled;
        expect(events.whereType<EmbeddedTorReady>(), isEmpty);
      },
    );

    test('stop interrupts a pending listener check', () async {
      final checking = Completer<void>();
      final listenerResult = Completer<bool>();
      service.checkListener = () {
        if (!checking.isCompleted) checking.complete();
        return listenerResult.future;
      };
      final starting = backend.start(TorTransport.direct);
      final cancelled = expectLater(
        starting,
        throwsA(isA<TorBackendException>()),
      );
      await holding.future;
      releaseHold.complete();
      await checking.future;
      await backend.stop();
      await cancelled;
      listenerResult.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<EmbeddedTorReady>(), isEmpty);
    });

    test('a regression cannot extend the startup readiness budget', () async {
      await backend.close();
      backend = OnionTorBackend(
        const TorLogger(),
        launcher: _ReadinessLauncher(service),
        directories: (_) async => torDirectoriesUnder(root.path),
        readinessHold: Duration.zero,
        trafficReadyTimeout: const Duration(milliseconds: 30),
        wait: (_) async {
          service.statuses.add(status(0.45));
        },
      );
      events = [];
      backend.watch().listen(events.add);
      await expectLater(
        backend.start(TorTransport.direct),
        throwsA(
          isA<TorBackendException>().having(
            (error) => error.failure,
            'readiness deadline',
            isA<TorBootstrapTimeoutFailure>(),
          ),
        ),
      );
      service.statuses.add(status(1, ready: true));
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<EmbeddedTorReady>(), isEmpty);
    });

    test(
      'a listener check cannot outlive the startup readiness budget',
      () async {
        await backend.close();
        final listenerResult = Completer<bool>();
        service.checkListener = () => listenerResult.future;
        backend = OnionTorBackend(
          const TorLogger(),
          launcher: _ReadinessLauncher(service),
          directories: (_) async => torDirectoriesUnder(root.path),
          readinessHold: Duration.zero,
          trafficReadyTimeout: const Duration(milliseconds: 30),
        );
        events = [];
        backend.watch().listen(events.add);
        await expectLater(
          backend.start(TorTransport.direct),
          throwsA(
            isA<TorBackendException>().having(
              (error) => error.failure,
              'listener readiness deadline',
              isA<TorBootstrapTimeoutFailure>(),
            ),
          ),
        );
        listenerResult.complete(true);
        await Future<void>.delayed(Duration.zero);
        expect(events.whereType<EmbeddedTorReady>(), isEmpty);
      },
    );
  });

  group('adopting an existing client', () {
    late Directory root;
    late _ReadinessService service;
    late _ReadinessLauncher launcher;
    late OnionTorBackend backend;
    late List<EmbeddedTorEvent> events;
    late int holdCalls;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('tor_adoption_');
      service = _ReadinessService();
      launcher = _ReadinessLauncher(service);
      holdCalls = 0;
      backend = OnionTorBackend(
        const TorLogger(),
        launcher: launcher,
        directories: (_) async => torDirectoriesUnder(root.path),
        trafficReadyTimeout: const Duration(milliseconds: 50),
        wait: (_) async {
          holdCalls++;
        },
      );
      events = [];
      backend.watch().listen(events.add);
    });

    tearDown(() async {
      await backend.close();
      await service.statuses.close();
      await root.delete(recursive: true);
    });

    test(
      'waits for current readiness without restarting or another hold',
      () async {
        final endpoint = await backend.start(TorTransport.direct);
        service.statuses.add(status(0.45));
        events.clear();
        var completed = false;
        final adopting = backend.start(TorTransport.direct).then((value) {
          completed = true;
          return value;
        });
        await Future<void>.delayed(Duration.zero);

        expect(completed, isFalse);
        expect(events.whereType<EmbeddedTorReady>(), isEmpty);
        service.statuses.add(status(1, ready: true));
        expect(await adopting, endpoint);
        expect(launcher.startCalls, 1);
        expect(service.bootstrapCalls, 1);
        expect(service.stopCalls, 0);
        expect(holdCalls, 1);
      },
    );

    test('rechecks readiness after the adoption listener check', () async {
      final endpoint = await backend.start(TorTransport.direct);
      final checking = Completer<void>();
      final listenerResult = Completer<bool>();
      service.checkListener = () {
        if (!checking.isCompleted) checking.complete();
        return listenerResult.future;
      };
      var completed = false;
      final adopting = backend.start(TorTransport.direct).then((value) {
        completed = true;
        return value;
      });
      await checking.future;
      service.statuses.add(status(0.45));
      events.clear();
      listenerResult.complete(true);
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);
      expect(events.whereType<EmbeddedTorReady>(), isEmpty);
      service.statuses.add(status(1, ready: true));
      expect(await adopting, endpoint);
      expect(launcher.startCalls, 1);
      expect(service.bootstrapCalls, 1);
      expect(holdCalls, 1);
    });

    test('stop cancels adoption while readiness is regressed', () async {
      await backend.start(TorTransport.direct);
      service.statuses.add(status(0.45));
      final adopting = backend.start(TorTransport.direct);
      final cancelled = expectLater(
        adopting,
        throwsA(isA<TorBackendException>()),
      );
      await Future<void>.delayed(Duration.zero);
      await backend.stop();
      await cancelled;
      expect(service.bootstrapCalls, 1);
    });

    test('stop interrupts the first adoption listener check', () async {
      await backend.start(TorTransport.direct);
      final checking = Completer<void>();
      final listenerResult = Completer<bool>();
      service.checkListener = () {
        if (!checking.isCompleted) checking.complete();
        return listenerResult.future;
      };
      final adopting = backend.start(TorTransport.direct);
      final cancelled = expectLater(
        adopting,
        throwsA(isA<TorBackendException>()),
      );
      await checking.future;
      var stopped = false;
      final stopping = backend.stop().then((_) => stopped = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(stopped, isTrue);
      } finally {
        listenerResult.complete(true);
        await stopping;
        await cancelled;
      }
    });

    test(
      'adoption readiness has a deadline without another hold budget',
      () async {
        await backend.start(TorTransport.direct);
        service.statuses.add(status(0.45));
        await expectLater(
          backend.start(TorTransport.direct),
          throwsA(
            isA<TorBackendException>().having(
              (error) => error.failure,
              'adoption deadline',
              isA<TorBootstrapTimeoutFailure>(),
            ),
          ),
        );
        expect(holdCalls, 1);
        expect(service.bootstrapCalls, 1);
      },
    );
  });
}

final class _ReadinessLauncher implements OnionClientLauncher {
  final onion.TorService service;
  int startCalls = 0;

  _ReadinessLauncher(this.service);

  @override
  Future<onion.TorService> startClient(
    OnionClientConfig config,
    onion.SocksPolicy policy,
  ) async {
    startCalls++;
    return service;
  }

  @override
  Future<int> startSnowflakeProxy() async => throw UnimplementedError();

  @override
  Future<void> stopSnowflakeProxy() async {}
}

final class _ReadinessService implements onion.TorService {
  final statuses = StreamController<onion.TorStatus>.broadcast(sync: true);
  Future<bool> Function()? checkListener;
  int bootstrapCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> bootstrap() async {
    bootstrapCalls++;
    statuses.add(
      onion.TorStatus(
        fraction: 1,
        readyForTraffic: true,
        stage: '',
        transport: onion.TorTransport.direct,
      ),
    );
  }

  @override
  Future<bool> proxyIsAlive() async => await checkListener?.call() ?? true;

  @override
  Future<int> socksPort() async => 9050;

  @override
  Stream<onion.TorStatus> watchStatus() => statuses.stream;

  @override
  Future<void> setDormant({required bool dormant}) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
