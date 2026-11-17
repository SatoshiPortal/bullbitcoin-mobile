import 'dart:async';

import 'package:test/test.dart';
import 'package:bull_tor/src/data/tor_repository_impl.dart';
import 'package:bull_tor/src/domain/ports/embedded_tor_port.dart';
import 'package:bull_tor/src/domain/ports/external_tor_port.dart';
import 'package:bull_tor/src/domain/ports/network_presence_port.dart';
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

    group('a Snowflake retry asked by the user', () {
      test('automatic mode goes straight to Snowflake', () async {
        final pending = repository.retry(snowflake: true);
        await Future<void>.delayed(Duration.zero);
        expect(embedded.startedTransports, [TorTransport.snowflake]);

        embedded.starts.last.complete(
          TorProxyEndpoint(host: '127.0.0.1', port: 41004),
        );
        final state = await pending as TorReady;
        expect(state.route.transport, TorTransport.snowflake);
        expect(repository.mode, TorTransportMode.automatic);
      });

      test('an explicit direct mode stays direct', () async {
        await repository.close();
        embedded = _FakeEmbeddedTor();
        repository = TorRepositoryImpl(
          embedded,
          initialMode: TorTransportMode.direct,
        );
        unawaited(repository.retry(snowflake: true));
        await Future<void>.delayed(Duration.zero);
        expect(embedded.startedTransports, [TorTransport.direct]);
      });

      test('a direct retry already running does not absorb it', () async {
        unawaited(repository.retry());
        await Future<void>.delayed(Duration.zero);
        unawaited(repository.retry(snowflake: true));
        await Future<void>.delayed(Duration.zero);
        expect(embedded.startedTransports, [
          TorTransport.direct,
          TorTransport.snowflake,
        ]);
      });
    });

    group('attempt budgets', () {
      final t0 = DateTime.utc(2026, 11, 15, 12);

      Future<TorRepository> withBudgets({
        Duration direct = const Duration(minutes: 2),
        Duration snowflake = const Duration(minutes: 15),
        TorTransportMode mode = TorTransportMode.automatic,
      }) async {
        await repository.close();
        embedded = _FakeEmbeddedTor();
        return repository = TorRepositoryImpl(
          embedded,
          initialMode: mode,
          directBudget: direct,
          snowflakeBudget: snowflake,
          now: () => t0,
        );
      }

      test('each attempt announces when it will give up', () async {
        final repo = await withBudgets();
        final states = <TorConnectionState>[];
        final subscription = repo.watch().listen(states.add);
        addTearDown(subscription.cancel);
        unawaited(repo.ensureReady());
        await Future<void>.delayed(Duration.zero);

        final connecting = states.whereType<TorConnecting>().last;
        expect(connecting.deadline, t0.add(const Duration(minutes: 2)));
      });

      test('an expired direct budget falls back to Snowflake', () async {
        final repo = await withBudgets(
          direct: const Duration(milliseconds: 20),
          snowflake: const Duration(hours: 1),
        );
        final states = <TorConnectionState>[];
        final subscription = repo.watch().listen(states.add);
        addTearDown(subscription.cancel);
        unawaited(repo.ensureReady());
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(embedded.stopCalls, 1);
        expect(embedded.startedTransports, [
          TorTransport.direct,
          TorTransport.snowflake,
        ]);
        final snowflake = states.whereType<TorConnecting>().last;
        expect(snowflake.circumvention, isTrue);
        expect(snowflake.deadline, t0.add(const Duration(hours: 1)));
      });

      test(
        'an expired Snowflake budget stops Tor and fails as a timeout',
        () async {
          final repo = await withBudgets(
            snowflake: const Duration(milliseconds: 20),
            mode: TorTransportMode.snowflake,
          );
          final result = await repo.ensureReady();

          expect(embedded.stopCalls, 1);
          expect(
            result,
            isA<TorUnavailable>().having(
              (state) => state.failure,
              'failure',
              isA<TorBootstrapTimeoutFailure>(),
            ),
          );
        },
      );
    });

    group('on a network that blocks Tor relays', () {
      late _FakeNetwork network;

      setUp(() async {
        await repository.close();
        embedded = _FakeEmbeddedTor();
        network = _FakeNetwork();
        repository = TorRepositoryImpl(
          embedded,
          network: network,
          censorshipFallbackAfter: const Duration(milliseconds: 20),
        );
      });

      test('an offline verdict with a device network means no internet or a blocking network', () async {
        final states = <TorConnectionState>[];
        final subscription = repository.watch().listen(states.add);
        addTearDown(subscription.cancel);
        unawaited(repository.ensureReady());
        await Future<void>.delayed(Duration.zero);

        embedded.events.add(
          const EmbeddedTorConnecting(
            progress: 0,
            transport: TorTransport.direct,
            diagnostic: TorDiagnostic.offline,
          ),
        );

        await Future<void>.delayed(Duration.zero);
        final connecting = states.whereType<TorConnecting>().last;
        expect(connecting.diagnostic, TorDiagnostic.noInternetOrBlocked);
        // Not Tor's own filtering evidence, but Snowflake is still worth a try.
        expect(connecting.diagnostic?.suggestsCensorship, isFalse);
        expect(connecting.diagnostic?.worthSnowflake, isTrue);
      });

      test(
        'an offline verdict without a device network stays offline',
        () async {
          network.present = false;
          final states = <TorConnectionState>[];
          final subscription = repository.watch().listen(states.add);
          addTearDown(subscription.cancel);
          unawaited(repository.ensureReady());
          await Future<void>.delayed(Duration.zero);

          embedded.events.add(
            const EmbeddedTorConnecting(
              progress: 0,
              transport: TorTransport.direct,
              diagnostic: TorDiagnostic.offline,
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 60));

          expect(
            states.whereType<TorConnecting>().last.diagnostic,
            TorDiagnostic.offline,
          );
          expect(embedded.startedTransports, [TorTransport.direct]);
        },
      );

      test('persistent censorship switches to Snowflake and announces it', () async {
        final states = <TorConnectionState>[];
        final subscription = repository.watch().listen(states.add);
        addTearDown(subscription.cancel);
        final pending = repository.ensureReady();
        await Future<void>.delayed(Duration.zero);

        embedded.events.add(
          const EmbeddedTorConnecting(
            progress: 0,
            transport: TorTransport.direct,
            diagnostic: TorDiagnostic.offline,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));

        // The direct bootstrap never finished: the switch did not wait for it.
        expect(embedded.starts.first.isCompleted, isFalse);
        expect(embedded.stopCalls, 1);
        expect(embedded.startedTransports, [
          TorTransport.direct,
          TorTransport.snowflake,
        ]);
        final snowflake = states.whereType<TorConnecting>().last;
        expect(snowflake.transport, TorTransport.snowflake);
        expect(snowflake.circumvention, isTrue);

        embedded.starts.last.complete(
          TorProxyEndpoint(host: '127.0.0.1', port: 41003),
        );
        final state = await pending as TorReady;
        expect(state.route.transport, TorTransport.snowflake);
      });

      group('without a blockage verdict', () {
        setUp(() async {
          await repository.close();
          embedded = _FakeEmbeddedTor();
          repository = TorRepositoryImpl(
            embedded,
            network: network,
            stallFallbackAfter: const Duration(milliseconds: 30),
          );
        });

        test(
          'a direct bootstrap that stops progressing hands over to Snowflake',
          () async {
            final pending = repository.ensureReady();
            await Future<void>.delayed(Duration.zero);

            // Arti dips and returns to 85% without ever carrying traffic.
            for (final progress in [0.3, 0.85, 0.3, 0.85]) {
              embedded.events.add(
                EmbeddedTorConnecting(
                  progress: progress,
                  transport: TorTransport.direct,
                ),
              );
            }
            await Future<void>.delayed(const Duration(milliseconds: 80));

            expect(embedded.startedTransports, [
              TorTransport.direct,
              TorTransport.snowflake,
            ]);
            embedded.starts.last.complete(
              TorProxyEndpoint(host: '127.0.0.1', port: 41004),
            );
            final state = await pending as TorReady;
            expect(state.route.transport, TorTransport.snowflake);
          },
        );

        test('a direct bootstrap that never reports hands over too', () async {
          unawaited(repository.ensureReady());
          await Future<void>.delayed(const Duration(milliseconds: 80));

          expect(embedded.startedTransports, [
            TorTransport.direct,
            TorTransport.snowflake,
          ]);
        });

        test('steady progress keeps the direct attempt', () async {
          unawaited(repository.ensureReady());
          await Future<void>.delayed(Duration.zero);

          for (var step = 1; step <= 6; step++) {
            embedded.events.add(
              EmbeddedTorConnecting(
                progress: step / 10,
                transport: TorTransport.direct,
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 15));
          }

          expect(embedded.startedTransports, [TorTransport.direct]);
        });
      });

      test('a passing diagnostic does not switch transport', () async {
        unawaited(repository.ensureReady());
        await Future<void>.delayed(Duration.zero);

        embedded.events
          ..add(
            const EmbeddedTorConnecting(
              progress: 0,
              transport: TorTransport.direct,
              diagnostic: TorDiagnostic.offline,
            ),
          )
          ..add(
            const EmbeddedTorConnecting(
              progress: 0.4,
              transport: TorTransport.direct,
            ),
          );
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(embedded.startedTransports, [TorTransport.direct]);
        expect(embedded.stopCalls, 0);
      });
    });

    test('automatic mode remembers Snowflake without downgrading', () async {
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
      expect(embedded.startedTransports.last, TorTransport.snowflake);
      expect(
        embedded.startedTransports.where((t) => t == TorTransport.direct),
        hasLength(1),
      );
      embedded.starts.last.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41003),
      );
      await restarted;
    });

    test('restores the last successful automatic transport', () async {
      await repository.close();
      repository = TorRepositoryImpl(
        embedded,
        lastSuccessfulTransport: TorTransport.snowflake,
      );

      final pending = repository.ensureReady();
      await Future<void>.delayed(Duration.zero);

      expect(embedded.startedTransports, [TorTransport.snowflake]);
      embedded.starts.single.complete(
        TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      );
      await pending;
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

final class _FakeNetwork implements NetworkPresencePort {
  bool present = true;

  @override
  bool get hasNetwork => present;
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

  @override
  Future<TorProxyEndpoint> start(TorTransport transport) {
    startCalls++;
    startedTransports.add(transport);
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
  }

  @override
  Future<void> close() async {
    closeCalls++;
    await events.close();
  }

  @override
  Stream<EmbeddedTorEvent> watch() => events.stream;
}
