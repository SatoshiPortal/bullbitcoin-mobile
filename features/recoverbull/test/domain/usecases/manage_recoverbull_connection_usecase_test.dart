import 'dart:async';
import 'dart:io';

import 'package:bull_recoverbull/src/domain/entities/recoverbull_connection.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/connect_to_key_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_recoverbull_connection_usecase.dart';
import 'package:bull_tor/tor.dart' as tor;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../support/log_sink.dart';

class _Connect extends Mock implements ConnectToKeyServerUsecase {}

class _Ensure extends Mock implements EnsureRecoverBullTorSessionUsecase {}

class _Watch extends Mock implements tor.WatchTorConnectionUsecase {}

RecoverBullTorRoute _route({Future<void> Function()? onClose}) =>
    RecoverBullTorRoute(
      tor.TorRoute(
        source: tor.TorSource.embedded,
        endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: tor.TorReadinessEvidence.embeddedBootstrap,
      ),
      onClose ?? () async {},
      HttpClient(),
    );

void main() {
  late _Connect connect;
  late _Ensure ensure;
  late _Watch watch;
  late StreamController<tor.TorConnectionState> readiness;
  late ManageRecoverBullConnectionUsecase usecase;
  late RecoverBullTorRoute defaultRoute;
  setUpAll(() {
    registerFallbackValue((int _) {});
  });
  setUp(() {
    connect = _Connect();
    ensure = _Ensure();
    watch = _Watch();
    readiness = StreamController<tor.TorConnectionState>.broadcast(sync: true);
    defaultRoute = _route();
    when(watch.execute).thenAnswer((_) => readiness.stream);
    when(
      () => ensure.execute(restartEmbedded: any(named: 'restartEmbedded')),
    ).thenAnswer((_) async => Ok(defaultRoute));
    when(
      () => connect.execute(
        onAttempt: any(named: 'onAttempt'),
        route: any(named: 'route'),
      ),
    ).thenAnswer((invocation) async {
      final callback = invocation.namedArguments[#onAttempt];
      if (callback is void Function(int)) callback(1);
      return const Ok(true);
    });
    usecase = ManageRecoverBullConnectionUsecase(
      log: const TestLogSink(),
      connectToKeyServerUsecase: connect,
      ensureRecoverBullTorSessionUsecase: ensure,
      watchTorConnectionUsecase: watch,
    );
  });
  tearDown(() async {
    await usecase.close();
    await defaultRoute.closeQuietly();
    await readiness.close();
  });

  test('directory refresh keeps the verified route usable', () async {
    await usecase.execute(initialize: true);
    await pumpEventQueue();
    final route = usecase.route;
    readiness.add(const tor.TorConnecting(source: tor.TorSource.embedded));
    await pumpEventQueue();
    expect(usecase.state.torConnection, isA<tor.TorReady>());
    expect(usecase.route, same(route));
  });

  test(
    'terminal Tor state retires the route without rechecking the server',
    () async {
      await usecase.execute(initialize: true);
      await pumpEventQueue();
      clearInteractions(connect);
      readiness.add(const tor.TorStopped(tor.TorSource.embedded));
      await pumpEventQueue();
      expect(usecase.route, isNull);
      expect(usecase.state.keyServerStatus, KeyServerStatus.online);
      verifyNever(
        () => connect.execute(
          onAttempt: any(named: 'onAttempt'),
          route: any(named: 'route'),
        ),
      );
    },
  );

  test(
    'initialization reuses its own route and restart closes only that route',
    () async {
      var firstClosed = 0;
      var secondClosed = 0;
      final first = _route(onClose: () async => firstClosed++);
      final second = _route(onClose: () async => secondClosed++);
      when(
        () => ensure.execute(restartEmbedded: false),
      ).thenAnswer((_) async => Ok(first));
      when(
        () => ensure.execute(restartEmbedded: true),
      ).thenAnswer((_) async => Ok(second));
      await usecase.execute(initialize: true);
      await pumpEventQueue();
      await usecase.execute(initialize: true);
      await pumpEventQueue();
      expect(usecase.route, same(first));
      expect(firstClosed, 0);
      verify(() => ensure.execute(restartEmbedded: false)).called(1);
      await usecase.execute(initialize: true, restart: true);
      await pumpEventQueue();
      expect(firstClosed, 1);
      expect(secondClosed, 0);
      expect(usecase.route, same(second));
      await usecase.close();
      expect(secondClosed, 1);
      expect(usecase.route, isNull);
    },
  );

  test(
    'closing during route acquisition closes its late route exactly once',
    () async {
      final pending =
          Completer<Result<RecoverBullTorRoute, RecoverBullFailure>>();
      when(
        () => ensure.execute(restartEmbedded: false),
      ).thenAnswer((_) => pending.future);
      var closed = 0;
      final lateRoute = _route(onClose: () async => closed++);
      final initialization = usecase.execute(initialize: true);
      await pumpEventQueue();
      final closing = usecase.close();
      pending.complete(Ok(lateRoute));
      await initialization;
      await closing;
      expect(closed, 1);
      expect(usecase.route, isNull);
      verifyNever(
        () => connect.execute(
          onAttempt: any(named: 'onAttempt'),
          route: any(named: 'route'),
        ),
      );
    },
  );

  test('closing ignores late server replies', () async {
    final response = Completer<Result<bool, RecoverBullFailure>>();
    when(
      () => connect.execute(
        onAttempt: any(named: 'onAttempt'),
        route: any(named: 'route'),
      ),
    ).thenAnswer((_) => response.future);
    final updates = <RecoverBullConnection>[];
    final subscription = usecase.updates.listen(updates.add);
    await usecase.execute(initialize: true);
    await pumpEventQueue();
    readiness.add(const tor.TorConnecting(source: tor.TorSource.embedded));
    await usecase.close();
    final count = updates.length;
    response.complete(const Ok(true));
    await pumpEventQueue();
    expect(updates, hasLength(count));
    expect(usecase.route, isNull);
    await subscription.cancel();
  });
  test('readiness leaves an unrequested flow idle', () async {
    readiness.add(tor.TorReady(defaultRoute.route));
    await pumpEventQueue();
    expect(usecase.route, isNull);
    verifyNever(
      () => ensure.execute(restartEmbedded: any(named: 'restartEmbedded')),
    );
    verifyNever(
      () => connect.execute(
        onAttempt: any(named: 'onAttempt'),
        route: any(named: 'route'),
      ),
    );
  });

  test(
    'new route waits for an in-flight borrower before closing the old one',
    () async {
      var firstClosed = 0;
      final first = _route(onClose: () async => firstClosed++);
      final replacement = _route();
      when(
        () => ensure.execute(restartEmbedded: false),
      ).thenAnswer((_) async => Ok(first));
      when(
        () => ensure.execute(restartEmbedded: false, newRoute: true),
      ).thenAnswer((_) async => Ok(replacement));
      await usecase.execute(initialize: true);
      await pumpEventQueue();
      final release = Completer<void>();
      final borrowed = usecase.borrowRoute((route) {
        expect(route, same(first));
        return release.future;
      });
      await usecase.execute(newCircuit: true);
      await pumpEventQueue();
      expect(usecase.route, same(replacement));
      expect(firstClosed, 0);
      release.complete();
      await borrowed;
      expect(firstClosed, 1);
      verifyNever(() => ensure.execute(restartEmbedded: true));
      await replacement.closeQuietly();
    },
  );

  test('new route is ignored while acquisition is pending', () async {
    final pending =
        Completer<Result<RecoverBullTorRoute, RecoverBullFailure>>();
    when(
      () => ensure.execute(restartEmbedded: false),
    ).thenAnswer((_) => pending.future);
    final acquisition = usecase.execute(initialize: true);
    await usecase.execute(newCircuit: true);
    verify(() => ensure.execute(restartEmbedded: false)).called(1);
    verifyNever(() => ensure.execute(restartEmbedded: false, newRoute: true));
    pending.complete(Ok(defaultRoute));
    await acquisition;
  });

  test(
    'same-session retry preserves its failure until the response arrives',
    () async {
      when(
        () => connect.execute(
          onAttempt: any(named: 'onAttempt'),
          route: any(named: 'route'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          KeyServerUnavailableFailure.because(
            KeyServerUnreachableCause.onionUnreachable,
          ),
        ),
      );
      await usecase.execute(initialize: true);
      await pumpEventQueue();
      final failure = usecase.state.failure;
      expect(usecase.state.keyServerFailures, 1);
      final response = Completer<Result<bool, RecoverBullFailure>>();
      when(
        () => connect.execute(
          onAttempt: any(named: 'onAttempt'),
          route: any(named: 'route'),
        ),
      ).thenAnswer((_) => response.future);
      final retry = usecase.execute();
      expect(usecase.state.failure, same(failure));
      expect(usecase.state.keyServerStatus, KeyServerStatus.connecting);
      response.complete(const Ok(true));
      await retry;
      expect(usecase.state.failure, isNull);
      verify(() => ensure.execute(restartEmbedded: false)).called(1);
    },
  );
}
