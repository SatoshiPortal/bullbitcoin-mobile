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

/// Advances a scheduled callback without spending time or using real timers.
class _ManualTimer implements Timer {
  final void Function() callback;
  bool _active = true;
  _ManualTimer(this.callback);
  @override
  bool get isActive => _active;
  @override
  int get tick => _active ? 0 : 1;
  @override
  void cancel() => _active = false;
  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }
}

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
  late List<_ManualTimer> timers;
  late DateTime now;
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
    timers = [];
    now = DateTime.utc(2026);
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
      (invocation.namedArguments[#onAttempt] as void Function(int))(1);
      return const Ok(true);
    });
    usecase = ManageRecoverBullConnectionUsecase(
      log: const TestLogSink(),
      connectToKeyServerUsecase: connect,
      ensureRecoverBullTorSessionUsecase: ensure,
      watchTorConnectionUsecase: watch,
      now: () => now,
      scheduleTimer: (_, callback) {
        final timer = _ManualTimer(callback);
        timers.add(timer);
        return timer;
      },
    );
  });
  tearDown(() async {
    await usecase.close();
    await defaultRoute.closeQuietly();
    await readiness.close();
  });

  test(
    'a brief readiness dip stays ready and cancels its grace timer',
    () async {
      await usecase.execute(initialize: true);
      await pumpEventQueue();
      expect(usecase.state.keyServerStatus, KeyServerStatus.online);
      final ready = usecase.state.torConnection;
      readiness.add(const tor.TorConnecting(source: tor.TorSource.embedded));
      expect(usecase.state.torConnection, same(ready));
      expect(timers.single.isActive, isTrue);
      now = now.add(const Duration(seconds: 1));
      readiness.add(tor.TorReady(defaultRoute.route));
      expect(timers.single.isActive, isFalse);
      // Even a callback already dispatched at cancellation cannot publish loss.
      now = now.add(const Duration(seconds: 5));
      timers.single.callback();
      await pumpEventQueue();
      expect(usecase.state.torConnection, isA<tor.TorReady>());
    },
  );

  test(
    'durable readiness loss appears after the complete five-second grace',
    () async {
      await usecase.execute(initialize: true);
      await pumpEventQueue();
      readiness.add(const tor.TorConnecting(source: tor.TorSource.embedded));
      now = now.add(const Duration(seconds: 4));
      timers.single.fire();
      expect(usecase.state.torConnection, isA<tor.TorReady>());
      expect(timers, hasLength(2));
      now = now.add(const Duration(seconds: 1));
      timers.last.fire();
      await pumpEventQueue();
      expect(usecase.state.torConnection, isA<tor.TorConnecting>());
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

  test(
    'closing cancels readiness grace and ignores late server replies',
    () async {
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
      expect(timers.single.isActive, isFalse);
      now = now.add(const Duration(seconds: 6));
      timers.single.callback();
      response.complete(const Ok(true));
      await pumpEventQueue();
      expect(updates, hasLength(count));
      expect(usecase.route, isNull);
      await subscription.cancel();
    },
  );
}
