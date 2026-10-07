import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:bull_tor/src/data/tor_repository_impl.dart';
import 'package:bull_tor/src/domain/ports/embedded_tor_port.dart';
import 'package:bull_tor/src/domain/ports/external_tor_port.dart';
import 'package:bull_tor/src/domain/tor_repository.dart';
import 'package:bull_tor/src/domain/usecases/set_tor_dormant_usecase.dart';
import 'package:bull_tor/tor.dart';

void main() {
  group('TorProxyEndpoint', () {
    test('validates its port', () {
      expect(
        () => TorProxyEndpoint(host: '127.0.0.1', port: 0),
        throwsRangeError,
      );
      expect(
        TorProxyEndpoint(host: '127.0.0.1', port: 9050).authority,
        '127.0.0.1:9050',
      );
    });

    test('tryParse round-trips an authority', () {
      expect(
        TorProxyEndpoint.tryParse('127.0.0.1:9050'),
        TorProxyEndpoint(host: '127.0.0.1', port: 9050),
      );
    });

    // Hand-typed in the Electrum advanced options, so anything can arrive
    // here; an unusable value is null, never a throw.
    test('tryParse rejects malformed input instead of throwing', () {
      for (final input in [
        '',
        '127.0.0.1',
        ':9050',
        '127.0.0.1:',
        '127.0.0.1:not-a-port',
        '127.0.0.1:0',
        '127.0.0.1:65536',
      ]) {
        expect(TorProxyEndpoint.tryParse(input), isNull, reason: input);
      }
    });
  });

  group('TorRepository', () {
    late _FakeEmbeddedTor embedded;
    late TorRepository repository;

    setUp(() {
      embedded = _FakeEmbeddedTor();
      repository = TorRepositoryImpl(embedded);
    });

    tearDown(() => repository.close());

    test('watch emits the current state immediately', () async {
      expect(await repository.watch().first, isA<TorUninitialized>());
    });

    test('shares one start between concurrent callers', () async {
      final first = repository.ensureReady();
      final second = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);

      expect(embedded.starts, hasLength(1));
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41001);
      embedded.starts.single.complete(endpoint);

      final states = await Future.wait([first, second]);
      expect(states, everyElement(isA<TorReady>()));
      expect(embedded.startCalls, 1);
    });

    test('surfaces a failed bootstrap as unavailable', () async {
      final pending = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.single.completeError(
        const TorBackendException(TorBootstrapFailure('no directory')),
      );

      final state = await pending;
      expect(state, isA<TorUnavailable>());
      expect((state as TorUnavailable).failure, isA<TorBootstrapFailure>());
    });

    test('ignores completion from a generation replaced by retry', () async {
      final first = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      expect(embedded.starts, hasLength(1));

      final retry = repository.retry();
      await Future<void>.delayed(Duration.zero);
      expect(embedded.starts, hasLength(2));

      embedded.starts.first.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.current, isA<TorConnecting>());

      final currentEndpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41002);
      embedded.starts.last.complete(currentEndpoint);

      await first;
      final state = await retry;
      expect(state, isA<TorReady>());
      expect((state as TorReady).route.endpoint, currentEndpoint);
      expect((repository.current as TorReady).route.endpoint, currentEndpoint);
    });

    test('a second retry joins the one already in flight', () async {
      final first = repository.retry();
      await Future<void>.delayed(Duration.zero);
      final second = repository.retry();
      await Future<void>.delayed(Duration.zero);

      expect(embedded.starts, hasLength(1));
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41001);
      embedded.starts.single.complete(endpoint);

      await Future.wait([first, second]);
      expect(embedded.startCalls, 1);
    });

    test(
      'forwards non-monotonic embedded state without latching ready',
      () async {
        final states = <TorConnectionState>[];
        final subscription = repository.watch().listen(states.add);
        final pending = repository.ensureReady();
        await Future<void>.delayed(Duration.zero);

        final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41001);
        embedded.events.add(EmbeddedTorReady(endpoint, TorTransport.direct));
        embedded.events.add(
          const EmbeddedTorConnecting(
            progress: 0.45,
            transport: TorTransport.direct,
            diagnostic: TorDiagnostic.offline,
          ),
        );

        expect(repository.current, isA<TorConnecting>());
        expect((repository.current as TorConnecting).progress, 0.45);

        embedded.starts.single.complete(endpoint);
        await pending;
        await subscription.cancel();
        expect(states.whereType<TorReady>(), isNotEmpty);
        expect(states.whereType<TorConnecting>(), isNotEmpty);
      },
    );

    test('forwards the bootstrap detail arti gave', () async {
      final pending = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);

      embedded.events.add(
        const EmbeddedTorConnecting(
          progress: 0.3,
          transport: TorTransport.direct,
          diagnostic: TorDiagnostic.clockSkewed,
          detail: TorBootstrapDetail(blockage: 'Clock is skewed by 2 hours'),
        ),
      );

      final connecting = repository.current as TorConnecting;
      expect(connecting.detail?.blockage, 'Clock is skewed by 2 hours');
      embedded.starts.single.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      );
      await pending;
    });

    test('restarts embedded Tor when the cached listener died', () async {
      final first = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      final firstEndpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41001);
      embedded.starts.single.complete(firstEndpoint);
      await first;

      embedded.alive = false;
      final restarted = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      final secondEndpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41002);
      embedded.starts.last.complete(secondEndpoint);

      final state = await restarted;
      expect(embedded.startCalls, 2);
      expect((state as TorReady).route.endpoint, secondEndpoint);
    });

    test('reports a dead cached session for route invalidation', () async {
      var invalidations = 0;
      final repository = TorRepositoryImpl(
        embedded,
        onSessionInvalidated: () async => invalidations++,
      );
      addTearDown(repository.close);
      final first = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.single.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      );
      await first;

      embedded.alive = false;
      final restarted = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.last.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41002),
      );
      await restarted;
      expect(invalidations, 1);
    });

    test('adopts a client that is still serving traffic', () async {
      final first = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.single.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      );
      await first;

      expect(await repository.ensureReady(), isA<TorReady>());
      expect(embedded.startCalls, 1);
    });

    // Arti reports Connecting again while a live SOCKS route keeps serving, so
    // ensureReady must not stop-first: that would turn a hiccup into a full
    // re-bootstrap. retry() keeps its teardown, which the generation tests pin.
    test('ensureReady during a readiness dip does not tear down', () async {
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41001);
      final pending = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.single.complete(endpoint);
      await pending;

      embedded.events.add(
        const EmbeddedTorConnecting(
          progress: 0.45,
          transport: TorTransport.direct,
        ),
      );
      expect(repository.current, isA<TorConnecting>());

      embedded.alive = true;
      final second = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      if (embedded.starts.length > 1) embedded.starts.last.complete(endpoint);
      await second;

      expect(embedded.stopCalls, 0);
    });

    test('forwards mobile dormancy to embedded Tor', () async {
      final usecase = SetTorDormantUsecase(repository);

      await usecase.execute(true);
      await usecase.execute(false);

      expect(embedded.dormancyChanges, [true, false]);
    });

    test('automatic mode falls back once to Snowflake when filtered', () async {
      final pending = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.single.completeError(
        const TorBackendException(
          TorBootstrapFailure('filtered', TorDiagnostic.filtering),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(embedded.startedTransports, [
        TorTransport.direct,
        TorTransport.snowflake,
      ]);
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41002);
      embedded.starts.last.complete(endpoint);

      final state = await pending as TorReady;
      expect(state.route.transport, TorTransport.snowflake);
    });

    // Snowflake is the slow road: a session that once needed it, because
    // direct was merely slow, must get the chance to go back to direct.
    test('automatic mode retries direct after a Snowflake success', () async {
      final first = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.single.completeError(
        const TorBackendException(TorBootstrapTimeoutFailure('timeout')),
      );
      await Future<void>.delayed(Duration.zero);
      embedded.starts.last.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41002),
      );
      await first;

      embedded.alive = false;
      final restarted = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      expect(embedded.startedTransports, [
        TorTransport.direct,
        TorTransport.snowflake,
        TorTransport.direct,
      ]);
      embedded.starts.last.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41003),
      );
      await restarted;
    });

    // Censorship is the one reason to keep skipping direct: the network that
    // filtered it a moment ago will filter it again, and every reconnection
    // would otherwise pay for rediscovering that.
    test(
      'automatic mode stays on Snowflake once direct looked censored',
      () async {
        final first = repository.ensureReady();
        await Future<void>.delayed(Duration.zero);
        embedded.starts.single.completeError(
          const TorBackendException(
            TorBootstrapFailure('filtered', TorDiagnostic.filtering),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        embedded.starts.last.complete(
          TorProxyEndpoint(host: '127.0.0.1', port: 41002),
        );
        await first;

        embedded.alive = false;
        final restarted = repository.ensureReady();
        await Future<void>.delayed(Duration.zero);
        expect(embedded.startedTransports, [
          TorTransport.direct,
          TorTransport.snowflake,
          TorTransport.snowflake,
        ]);
        embedded.starts.last.complete(
          TorProxyEndpoint(host: '127.0.0.1', port: 41003),
        );
        await restarted;
      },
    );

    test('choosing a mode again forgets that direct looked censored', () async {
      final first = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.single.completeError(
        const TorBackendException(
          TorBootstrapFailure('filtered', TorDiagnostic.cantReachTor),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      embedded.starts.last.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41002),
      );
      await first;

      final direct = repository.setMode(TorTransportMode.direct);
      await Future<void>.delayed(Duration.zero);
      embedded.starts.last.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41003),
      );
      await direct;
      final automatic = repository.setMode(TorTransportMode.automatic);
      await Future<void>.delayed(Duration.zero);

      expect(embedded.startedTransports.last, TorTransport.direct);
      embedded.starts.last.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41004),
      );
      await automatic;
    });

    test('reports a successful transport for persistence', () async {
      await repository.close();
      final persisted = <TorTransport>[];
      repository = TorRepositoryImpl(
        embedded,
        onSuccessfulTransport: (transport) async => persisted.add(transport),
      );

      final pending = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.single.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      );
      await pending;
      await Future<void>.delayed(Duration.zero);

      expect(persisted, [TorTransport.direct]);
    });

    test('opens an isolated session only after Tor is ready', () async {
      final sessionFuture = repository.openSession();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.single.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      );

      final session = await sessionFuture;

      expect(session.endpoint.port, 42001);
      expect(session.transport, TorTransport.direct);
      expect(embedded.openSessionCalls, 1);
      await session.close();
      expect(embedded.closedSessionCalls, 1);
    });

    test('opens a session from the replacement transport generation', () async {
      final initialReady = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);
      embedded.starts.single.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      );
      await initialReady;

      final aliveCheck = Completer<bool>();
      embedded.aliveCheck = aliveCheck;
      final sessionFuture = repository.openSession();
      await Future<void>.delayed(Duration.zero);

      final modeChange = repository.setMode(TorTransportMode.snowflake);
      await Future<void>.delayed(Duration.zero);
      expect(embedded.starts, hasLength(2));

      aliveCheck.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(embedded.openSessionCalls, 0);

      embedded.starts.last.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41002),
      );
      await modeChange;
      final session = await sessionFuture;

      expect(session.transport, TorTransport.snowflake);
      expect(embedded.openSessionCalls, 1);
    });

    test('closing releases the backend, not just the running client', () async {
      await repository.close();

      expect(embedded.closeCalls, 1);
      // Idempotent: the shell may close a controller that already went away.
      await repository.close();
      expect(embedded.closeCalls, 1);
    });
  });

  // Automatic mode gives direct as long as it keeps moving, and no longer:
  // Snowflake is slower but works on networks where direct never will, so a
  // stuck direct bootstrap must hand over well before arti's own 120 s budget.
  group('automatic Snowflake fallback', () {
    late _FakeEmbeddedTor embedded;

    const stalled = EmbeddedTorConnecting(
      progress: 0,
      transport: TorTransport.direct,
    );
    EmbeddedTorConnecting directAt(double progress) => EmbeddedTorConnecting(
      progress: progress,
      transport: TorTransport.direct,
    );

    setUp(() => embedded = _FakeEmbeddedTor());

    TorRepositoryImpl startAutomatic(FakeAsync async) {
      final repository = TorRepositoryImpl(embedded);
      repository.ensureReady().ignore();
      async.flushMicrotasks();
      embedded.events.add(stalled);
      return repository;
    }

    test('keeps waiting on direct while its bootstrap progresses', () {
      fakeAsync((async) {
        final repository = startAutomatic(async);

        for (var step = 1; step <= 4; step++) {
          async.elapse(const Duration(seconds: 25));
          embedded.events.add(directAt(step * 0.2));
        }
        async.elapse(const Duration(seconds: 15));

        expect(embedded.startedTransports, [TorTransport.direct]);
        expect(embedded.stopCalls, 0);
        repository.close().ignore();
        async.flushMicrotasks();
      });
    });

    test('hands over to Snowflake after 30 s without progress', () {
      fakeAsync((async) {
        final repository = startAutomatic(async);

        async.elapse(const Duration(seconds: 10));
        embedded.events.add(directAt(0.1));
        async.elapse(const Duration(seconds: 15));
        // Repeating the same fraction is not progress.
        embedded.events.add(directAt(0.1));
        async.elapse(const Duration(seconds: 14));
        expect(embedded.startedTransports, [TorTransport.direct]);

        async.elapse(const Duration(seconds: 1));
        expect(embedded.stopCalls, 1);
        expect(embedded.startedTransports, [
          TorTransport.direct,
          TorTransport.snowflake,
        ]);

        embedded.starts.last.complete(
          TorProxyEndpoint(host: '127.0.0.1', port: 41002),
        );
        async.flushMicrotasks();
        final ready = repository.current as TorReady;
        expect(ready.route.transport, TorTransport.snowflake);
        repository.close().ignore();
        async.flushMicrotasks();
      });
    });

    test('hands over at once when the blockage suggests censorship', () {
      fakeAsync((async) {
        final repository = startAutomatic(async);

        async.elapse(const Duration(seconds: 2));
        embedded.events.add(
          const EmbeddedTorConnecting(
            progress: 0.1,
            transport: TorTransport.direct,
            diagnostic: TorDiagnostic.filtering,
          ),
        );
        async.flushMicrotasks();

        expect(embedded.stopCalls, 1);
        expect(embedded.startedTransports.last, TorTransport.snowflake);
        repository.close().ignore();
        async.flushMicrotasks();
      });
    });

    // Arti counts its first relay connection as 15% of the bootstrap, so a
    // fraction from 15% up means a TLS handshake with a relay succeeded: the
    // path is not censored, and silence after that is a directory download.
    // Measured on a Pixel 5: a cold start sits silent at 45% and a warm cache
    // at 30%, for 30 to 41 s on a healthy network. Only the 120 s limit and a
    // censorship blockage still hand over.
    group('once direct reached a relay', () {
      test('waits through a silent directory download', () {
        fakeAsync((async) {
          final repository = startAutomatic(async);

          async.elapse(const Duration(seconds: 3));
          embedded.events.add(directAt(0.3));
          async.elapse(const Duration(seconds: 60));

          expect(embedded.startedTransports, [TorTransport.direct]);
          expect(embedded.stopCalls, 0);
          repository.close().ignore();
          async.flushMicrotasks();
        });
      });

      test('still hands over at the 120 s limit', () {
        fakeAsync((async) {
          final repository = startAutomatic(async);

          async.elapse(const Duration(seconds: 3));
          embedded.events.add(directAt(0.15));
          async.elapse(const Duration(seconds: 116));
          expect(embedded.startedTransports, [TorTransport.direct]);

          async.elapse(const Duration(seconds: 1));
          expect(embedded.startedTransports.last, TorTransport.snowflake);
          repository.close().ignore();
          async.flushMicrotasks();
        });
      });

      test(
        'still hands over at once when the blockage suggests censorship',
        () {
          fakeAsync((async) {
            final repository = startAutomatic(async);

            embedded.events.add(directAt(0.3));
            async.elapse(const Duration(seconds: 40));
            embedded.events.add(
              const EmbeddedTorConnecting(
                progress: 0.3,
                transport: TorTransport.direct,
                diagnostic: TorDiagnostic.cantReachTor,
              ),
            );
            async.flushMicrotasks();

            expect(embedded.startedTransports.last, TorTransport.snowflake);
            repository.close().ignore();
            async.flushMicrotasks();
          });
        },
      );
    });

    test('hands over when silent for 30 s before reaching a relay', () {
      fakeAsync((async) {
        final repository = startAutomatic(async);

        embedded.events.add(directAt(0.1));
        async.elapse(const Duration(seconds: 29));
        expect(embedded.startedTransports, [TorTransport.direct]);

        async.elapse(const Duration(seconds: 1));
        expect(embedded.startedTransports.last, TorTransport.snowflake);
        repository.close().ignore();
        async.flushMicrotasks();
      });
    });

    test('gives direct 120 s at most, even while it progresses', () {
      fakeAsync((async) {
        final repository = startAutomatic(async);

        for (var step = 1; step <= 5; step++) {
          async.elapse(const Duration(seconds: 20));
          embedded.events.add(directAt(step * 0.15));
        }
        async.elapse(const Duration(seconds: 19));
        expect(embedded.startedTransports, [TorTransport.direct]);

        async.elapse(const Duration(seconds: 1));
        expect(embedded.startedTransports.last, TorTransport.snowflake);
        repository.close().ignore();
        async.flushMicrotasks();
      });
    });

    test('a direct attempt abandoned for Snowflake stays silent', () {
      fakeAsync((async) {
        final repository = startAutomatic(async);
        async.elapse(const Duration(seconds: 30));

        // The backend reports the cancelled direct start after the fact.
        embedded.starts.first.completeError(
          const TorBackendException(TorUnexpectedFailure('cancelled')),
        );
        async.flushMicrotasks();

        expect(repository.current, isA<TorConnecting>());
        expect(embedded.startedTransports.last, TorTransport.snowflake);
        repository.close().ignore();
        async.flushMicrotasks();
      });
    });

    // Stopping the abandoned direct client makes the real backend publish
    // Stopped, and a status stream torn down mid-bootstrap may publish Failed.
    // Neither ends the automatic sequence: Snowflake is starting, so whoever
    // waits for readiness must keep waiting and see no terminal state.
    test('keeps waiters waiting through the hand-over to Snowflake', () {
      fakeAsync((async) {
        embedded
          ..announcesStart = true
          ..stopEvents = const [
            EmbeddedTorFailed(TorUnexpectedFailure('status stream closed')),
            EmbeddedTorStopped(),
          ];
        final repository = TorRepositoryImpl(embedded);
        final states = <TorConnectionState>[];
        repository.watch().listen(states.add);
        TorConnectionState? outcome;
        repository.ensureReady().then((state) => outcome = state);
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 30));
        expect(embedded.startedTransports.last, TorTransport.snowflake);
        expect(outcome, isNull);

        embedded.starts.last.complete(
          TorProxyEndpoint(host: '127.0.0.1', port: 41002),
        );
        async.flushMicrotasks();

        expect((outcome as TorReady?)?.route.transport, TorTransport.snowflake);
        expect(
          states.skip(1).where((s) => s is TorStopped || s is TorUnavailable),
          isEmpty,
        );
        repository.close().ignore();
        async.flushMicrotasks();
      });
    });

    test('still reports Tor stopping once it was ready', () {
      fakeAsync((async) {
        embedded.announcesStart = true;
        final repository = TorRepositoryImpl(embedded);
        repository.ensureReady().ignore();
        async.flushMicrotasks();
        embedded.starts.last.complete(
          TorProxyEndpoint(host: '127.0.0.1', port: 41001),
        );
        async.flushMicrotasks();
        expect(repository.current, isA<TorReady>());

        embedded.events.add(const EmbeddedTorStopped());

        expect(repository.current, isA<TorStopped>());
        repository.close().ignore();
        async.flushMicrotasks();
      });
    });

    // Snowflake cannot fix a device that is offline or has a wrong clock, so
    // these must neither burn the stall budget nor end on Snowflake.
    test('does not count time spent offline as a stall', () {
      fakeAsync((async) {
        final repository = startAutomatic(async);

        async.elapse(const Duration(seconds: 5));
        embedded.events.add(
          const EmbeddedTorConnecting(
            progress: 0,
            transport: TorTransport.direct,
            diagnostic: TorDiagnostic.offline,
          ),
        );
        async.elapse(const Duration(seconds: 55));
        expect(embedded.startedTransports, [TorTransport.direct]);

        // Back online without progress yet: the stall clock starts again.
        embedded.events.add(stalled);
        async.elapse(const Duration(seconds: 29));
        expect(embedded.startedTransports, [TorTransport.direct]);
        async.elapse(const Duration(seconds: 1));
        expect(embedded.startedTransports.last, TorTransport.snowflake);
        repository.close().ignore();
        async.flushMicrotasks();
      });
    });

    for (final (diagnostic, detail) in [
      (TorDiagnostic.offline, 'unable to connect to the internet'),
      (TorDiagnostic.clockSkewed, 'Clock is skewed by 2 hours'),
    ]) {
      test(
        'gives up without Snowflake when still ${diagnostic.name} at 120 s',
        () {
          fakeAsync((async) {
            final repository = startAutomatic(async);
            embedded.events.add(
              EmbeddedTorConnecting(
                progress: 0,
                transport: TorTransport.direct,
                diagnostic: diagnostic,
                detail: TorBootstrapDetail(blockage: detail),
              ),
            );

            async.elapse(const Duration(seconds: 120));

            expect(embedded.startedTransports, [TorTransport.direct]);
            expect(embedded.stopCalls, 1);
            final state = repository.current as TorUnavailable;
            final failure = state.failure as TorBootstrapFailure;
            expect(failure.diagnostic, diagnostic);
            expect(failure.detail?.blockage, detail);
            repository.close().ignore();
            async.flushMicrotasks();
          });
        },
      );
    }

    test('direct mode never abandons a slow bootstrap', () {
      fakeAsync((async) {
        final repository = TorRepositoryImpl(
          embedded,
          initialMode: TorTransportMode.direct,
        );
        repository.ensureReady().ignore();
        async.flushMicrotasks();
        embedded.events.add(stalled);

        async.elapse(const Duration(minutes: 5));

        expect(embedded.startedTransports, [TorTransport.direct]);
        expect(embedded.stopCalls, 0);
        repository.close().ignore();
        async.flushMicrotasks();
      });
    });
  });

  // The external proxy is verified on its own: no repository, no lifecycle, no fallback.
  // between the two sources.
  test(
    'VerifyExternalTorUsecase verifies only the supplied endpoint',
    () async {
      final external = _FakeExternalTor();
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 9050);
      final usecase = VerifyExternalTorUsecase(external);

      final state = await usecase.execute(endpoint);

      expect(state, isA<TorReady>());
      expect((state as TorReady).route.source, TorSource.external);
      expect(external.verified, [endpoint]);
    },
  );

  test('VerifyExternalTorUsecase reports an unreachable proxy', () async {
    final external = _FakeExternalTor()
      ..failure = const TorBackendException(
        TorExternalProxyUnavailableFailure('connection refused'),
      );
    final usecase = VerifyExternalTorUsecase(external);

    final state = await usecase.execute(
      TorProxyEndpoint(host: '127.0.0.1', port: 9050),
    );

    expect(state, isA<TorUnavailable>());
    expect((state as TorUnavailable).source, TorSource.external);
  });
}

final class _FakeExternalTor implements ExternalTorPort {
  final List<TorProxyEndpoint> verified = [];
  TorBackendException? failure;

  @override
  Future<void> verify(TorProxyEndpoint endpoint) async {
    verified.add(endpoint);
    final error = failure;
    if (error != null) throw error;
  }
}

final class _FakeEmbeddedTor implements EmbeddedTorPort {
  final StreamController<EmbeddedTorEvent> events =
      StreamController<EmbeddedTorEvent>.broadcast(sync: true);
  final List<Completer<TorProxyEndpoint>> starts = [];
  final List<bool> dormancyChanges = [];
  final List<TorTransport> startedTransports = [];
  int startCalls = 0;
  int stopCalls = 0;
  int closeCalls = 0;
  int openSessionCalls = 0;
  int closedSessionCalls = 0;
  bool alive = true;
  Completer<bool>? aliveCheck;

  /// What the backend publishes while stopping, as `OnionTorBackend` does.
  List<EmbeddedTorEvent> stopEvents = const [];

  /// Whether a start announces itself like `OnionTorBackend`: stopped, then
  /// connecting at zero.
  bool announcesStart = false;

  @override
  Future<TorProxyEndpoint> start(TorTransport transport) {
    startCalls++;
    startedTransports.add(transport);
    if (announcesStart) {
      events
        ..add(const EmbeddedTorStopped())
        ..add(EmbeddedTorConnecting(progress: 0, transport: transport));
    }
    final completer = Completer<TorProxyEndpoint>();
    starts.add(completer);
    return completer.future;
  }

  @override
  Future<bool> isAlive() => aliveCheck?.future ?? Future.value(alive);

  @override
  Future<TorSession> openSession() async {
    openSessionCalls++;
    return TorSession(
      TorProxyEndpoint(host: '127.0.0.1', port: 42001),
      startedTransports.last,
      () async => closedSessionCalls++,
    );
  }

  @override
  Future<void> setDormant(bool dormant) async {
    dormancyChanges.add(dormant);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    stopEvents.forEach(events.add);
  }

  @override
  Future<void> close() async {
    closeCalls++;
    await events.close();
  }

  @override
  Stream<EmbeddedTorEvent> watch() => events.stream;
}
