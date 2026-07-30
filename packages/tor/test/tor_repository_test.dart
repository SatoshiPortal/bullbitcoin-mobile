import 'dart:async';

import 'package:test/test.dart';
import 'package:tor/src/data/tor_repository_impl.dart';
import 'package:tor/src/domain/ports/embedded_tor_port.dart';
import 'package:tor/src/domain/ports/external_tor_port.dart';
import 'package:tor/src/domain/tor_repository.dart';
import 'package:tor/src/domain/usecases/set_tor_dormant_usecase.dart';
import 'package:tor/tor.dart';

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

  // Orbot is verified on its own: no repository, no lifecycle, no fallback
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
