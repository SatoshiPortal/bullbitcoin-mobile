import 'dart:async';

import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resync_sp_listener_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:bb_mobile/features/sp/watchers/sp_electrum_reconnect_watcher.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class _FakeResyncSpListenerUsecase implements ResyncSpListenerUsecase {
  int calls = 0;
  Result<void, SpFailure> result = const Ok(null);

  @override
  Future<Result<void, SpFailure>> execute() async {
    calls++;
    return result;
  }
}

class _FakeWatchSpNotificationLogUsecase
    implements WatchSpNotificationLogUsecase {
  final StreamController<SpNotifLogLine> lines =
      StreamController<SpNotifLogLine>.broadcast();

  @override
  ({List<SpNotifLogLine> log, Stream<SpNotifLogLine> updates}) execute() =>
      (log: const [], updates: lines.stream);
}

void main() {
  const firstBackoff = SpElectrumReconnectWatcher.firstBackoff;
  const maxAttempts = SpElectrumReconnectWatcher.maxAttempts;
  const tick = Duration(milliseconds: 1);

  late _FakeResyncSpListenerUsecase resync;
  late _FakeWatchSpNotificationLogUsecase log;
  late StreamController<AppLifecycleState> lifecycle;
  late SpElectrumReconnectWatcher watcher;

  void setLifecycle(FakeAsync async, AppLifecycleState state) {
    lifecycle.add(state);
    async.flushMicrotasks();
  }

  setUp(() {
    resync = _FakeResyncSpListenerUsecase();
    log = _FakeWatchSpNotificationLogUsecase();
    lifecycle = StreamController<AppLifecycleState>.broadcast();
    watcher = SpElectrumReconnectWatcher(
      watchSpNotificationLogUsecase: log,
      resyncSpListenerUsecase: resync,
      lifecycleStates: lifecycle.stream,
      initialLifecycleState: AppLifecycleState.resumed,
    );
  });

  tearDown(() => lifecycle.close());

  void emit(FakeAsync async, SpNotification n) {
    log.lines.add(SpNotifLogLine(time: DateTime.now(), notification: n));
    async.flushMicrotasks();
  }

  const drop = SpElectrumDisconnected();
  const connected = SpElectrumConnected();
  const headerProgress = SpHeaderProgress(
    phase: SpHeaderValidationPhase.initialSync,
    current: 10,
    end: 20,
  );

  test('a drop restarts the listener after the first backoff', () {
    fakeAsync((async) {
      watcher.start();
      emit(async, drop);

      async.elapse(firstBackoff - tick);
      expect(resync.calls, 0);

      async.elapse(tick);
      expect(resync.calls, 1);
      expect(watcher.attempts, 1);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('until the listener connects, each restart arms the next one with a '
      'doubled backoff', () {
    fakeAsync((async) {
      watcher.start();
      emit(async, drop);

      async.elapse(firstBackoff);
      expect(resync.calls, 1);

      async.elapse(firstBackoff * 2 - tick);
      expect(resync.calls, 1);

      async.elapse(tick);
      expect(resync.calls, 2);

      async.elapse(firstBackoff * 4);
      expect(resync.calls, 3);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('a failed restart keeps the round going', () {
    fakeAsync((async) {
      resync.result = const Err(SpUnexpected('electrum down'));
      watcher.start();
      emit(async, drop);

      async.elapse(firstBackoff * 3);

      expect(resync.calls, 2);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('the round stops after the attempts run out', () {
    fakeAsync((async) {
      watcher.start();
      emit(async, drop);

      async.elapse(firstBackoff * (1 << (maxAttempts + 1)));

      expect(resync.calls, maxAttempts);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('a connect after a restart ends the round', () {
    fakeAsync((async) {
      watcher.start();
      emit(async, drop);
      async.elapse(firstBackoff);
      expect(resync.calls, 1);

      emit(async, connected);
      async.elapse(firstBackoff * 8);

      expect(resync.calls, 1);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('a connect before the first restart cancels it', () {
    fakeAsync((async) {
      watcher.start();
      emit(async, drop);
      emit(async, connected);

      async.elapse(firstBackoff * 8);

      expect(resync.calls, 0);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('header progress does not end the round', () {
    fakeAsync((async) {
      watcher.start();
      emit(async, drop);
      async.elapse(firstBackoff);

      emit(async, headerProgress);
      async.elapse(firstBackoff * 2);

      expect(resync.calls, 2);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('a drop in the background waits for the resume', () {
    fakeAsync((async) {
      watcher.start();
      setLifecycle(async, AppLifecycleState.paused);
      emit(async, drop);

      async.elapse(firstBackoff * 8);
      expect(resync.calls, 0);

      setLifecycle(async, AppLifecycleState.resumed);
      async.elapse(firstBackoff);
      expect(resync.calls, 1);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('leaving the foreground cancels the pending restart', () {
    fakeAsync((async) {
      watcher.start();
      emit(async, drop);

      setLifecycle(async, AppLifecycleState.paused);
      async.elapse(firstBackoff * 8);

      expect(resync.calls, 0);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('a resume after the attempts ran out starts a new round', () {
    fakeAsync((async) {
      watcher.start();
      emit(async, drop);
      async.elapse(firstBackoff * (1 << (maxAttempts + 1)));
      expect(resync.calls, maxAttempts);

      setLifecycle(async, AppLifecycleState.paused);
      setLifecycle(async, AppLifecycleState.resumed);
      async.elapse(firstBackoff);

      expect(resync.calls, maxAttempts + 1);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('a drop after the attempts ran out restarts nothing and warns once', () {
    final warnings = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null && message.contains('still disconnected')) {
        warnings.add(message);
      }
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    fakeAsync((async) {
      watcher.start();
      emit(async, drop);
      // The last attempt runs once every backoff before it has elapsed.
      async.elapse(firstBackoff * ((1 << maxAttempts) - 1));
      expect(resync.calls, maxAttempts);
      expect(warnings, hasLength(1));

      emit(async, drop);
      async.elapse(firstBackoff * 8);

      expect(resync.calls, maxAttempts);
      expect(warnings, hasLength(1));

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test(
    'inactive neither cancels the pending restart nor resets the attempts',
    () {
      fakeAsync((async) {
        watcher.start();
        emit(async, drop);
        async.elapse(firstBackoff);
        expect(resync.calls, 1);

        setLifecycle(async, AppLifecycleState.inactive);
        setLifecycle(async, AppLifecycleState.resumed);

        async.elapse(firstBackoff * 2 - tick);
        expect(resync.calls, 1);

        async.elapse(tick);
        expect(resync.calls, 2);
        expect(watcher.attempts, 2);

        unawaited(watcher.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test('a resume with a live connection restarts nothing', () {
    fakeAsync((async) {
      watcher.start();
      emit(async, drop);
      async.elapse(firstBackoff);
      emit(async, connected);

      setLifecycle(async, AppLifecycleState.paused);
      setLifecycle(async, AppLifecycleState.resumed);
      async.elapse(firstBackoff * 8);

      expect(resync.calls, 1);

      unawaited(watcher.dispose());
      async.flushMicrotasks();
    });
  });

  test('dispose stops further restarts', () {
    fakeAsync((async) {
      watcher.start();
      unawaited(watcher.dispose());
      async.flushMicrotasks();

      emit(async, drop);
      async.elapse(firstBackoff * 8);

      expect(resync.calls, 0);
    });
  });
}
