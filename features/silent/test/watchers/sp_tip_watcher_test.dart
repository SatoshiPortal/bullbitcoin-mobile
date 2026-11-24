import 'package:primitives/primitives.dart';

import 'dart:async';

import 'package:silent/src/domain/entities/sp_notif_log.dart';
import 'package:silent/src/domain/entities/sp_notification.dart';
import 'package:silent/src/domain/entities/sp_update.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:silent/src/watchers/sp_tip_watcher.dart';
import 'package:silent/src/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchSpUpdatesUsecase extends Mock
    implements WatchSpUpdatesUsecase {}

class _MockWatchSpNotificationLogUsecase extends Mock
    implements WatchSpNotificationLogUsecase {}

class _MockSyncSpWalletUsecase extends Mock implements SyncSpWalletUsecase {}

void main() {
  late StreamController<SilentUpdate> updates;
  late StreamController<SpNotifLogLine> notificationLog;
  late StreamController<bool> foreground;
  late _MockWatchSpUpdatesUsecase watchUsecase;
  late _MockWatchSpNotificationLogUsecase notificationUsecase;
  late _MockSyncSpWalletUsecase syncUsecase;
  late SpTipWatcher watcher;

  setUp(() {
    updates = StreamController<SilentUpdate>.broadcast();
    notificationLog = StreamController<SpNotifLogLine>.broadcast();
    foreground = StreamController<bool>.broadcast();
    watchUsecase = _MockWatchSpUpdatesUsecase();
    notificationUsecase = _MockWatchSpNotificationLogUsecase();
    syncUsecase = _MockSyncSpWalletUsecase();
    when(() => watchUsecase.execute()).thenAnswer((_) => updates.stream);
    when(notificationUsecase.execute).thenReturn((
      log: const <SpNotifLogLine>[],
      updates: notificationLog.stream,
    ));
    when(() => syncUsecase.execute())
        .thenAnswer((_) async => const Ok<void, SilentFailure>(null));
    when(() => syncUsecase.execute(resumeOnly: true))
        .thenAnswer((_) async => const Ok<void, SilentFailure>(null));
    watcher = SpTipWatcher(
      watchSpUpdatesUsecase: watchUsecase,
      syncSpWalletUsecase: syncUsecase,
      watchSpNotificationLogUsecase: notificationUsecase,
      foregroundChanges: foreground.stream,
      initiallyForeground: true,
    );
  });

  tearDown(() async {
    await watcher.dispose();
    await updates.close();
    await notificationLog.close();
    await foreground.close();
  });

  Future<void> emit(SilentUpdate update) async {
    updates.add(update);
    await Future<void>.delayed(Duration.zero);
  }

  // Direct add: the retry tests drive the clock themselves through
  // `fakeAsync`, so the helper must not await anything.
  void pushNotification(SpNotification notification) => notificationLog.add(
    SpNotifLogLine(time: DateTime.now(), notification: notification),
  );

  // `start()` runs inside the test body on purpose: a subscription created in
  // `setUp` lives in the real zone, and the retry timers would then ignore the
  // fake clock the `fakeAsync` cases advance.
  test('a tip landing re-runs the sync', () async {
    watcher.start();
    await emit(const SilentChainTipChanged(900000));

    verify(() => syncUsecase.execute()).called(1);
  });

  test('the same tip repeated syncs only once', () async {
    watcher.start();
    await emit(const SilentChainTipChanged(900000));
    await emit(const SilentChainTipChanged(900000));

    verify(() => syncUsecase.execute()).called(1);
  });

  test('a new block syncs again', () async {
    watcher.start();
    await emit(const SilentChainTipChanged(900000));
    await emit(const SilentChainTipChanged(900001));

    verify(() => syncUsecase.execute()).called(2);
  });

  test('other updates never sync', () async {
    watcher.start();
    await emit(const SilentSetupChanged());
    await emit(SilentBalanceChanged(Sats.fromInt(1000)));

    verifyNever(() => syncUsecase.execute());
  });

  test('a sync failure is swallowed, the watcher stays alive', () async {
    watcher.start();
    when(() => syncUsecase.execute()).thenAnswer(
      (_) async => const Err<void, SilentFailure>(SilentUnexpected('boom')),
    );

    await emit(const SilentChainTipChanged(900000));
    await emit(const SilentChainTipChanged(900001));

    verify(() => syncUsecase.execute()).called(2);
  });

  test('a tip landing in the background never syncs', () async {
    watcher.start();
    foreground.add(false);
    await Future<void>.delayed(Duration.zero);

    await emit(const SilentChainTipChanged(900000));

    verifyNever(() => syncUsecase.execute());
  });

  test('dispose stops further syncs', () async {
    watcher.start();
    await watcher.dispose();

    updates.add(const SilentChainTipChanged(900000));
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => syncUsecase.execute());
  });

  // The retry tests run under `fakeAsync` rather than `testWidgets`: they need
  // the clock to advance past real timers, and the zone their listeners are
  // created in has to be the one that owns them.
  //
  // The retries are counted by the stub rather than by `verify`: mocktail
  // consumes a matched call once verified, which would make each later count
  // read as zero.
  late int retries;

  void setUpRetries({SilentFailure? failsWith}) {
    retries = 0;
    when(() => syncUsecase.execute(resumeOnly: true)).thenAnswer((_) async {
      retries++;
      if (failsWith == null) return const Ok<void, SilentFailure>(null);
      return Err<void, SilentFailure>(failsWith);
    });
  }

  test('a failed scan is retried, with a growing delay', () {
    fakeAsync((async) {
      setUpRetries(failsWith: const SilentBackendUnreachable('down'));

      watcher.start();
      pushNotification(const SpScanFailed(SilentUnexpected('boom')));
      async.flushMicrotasks();
      expect(retries, 0);

      async.elapse(const Duration(seconds: 1, milliseconds: 999));
      expect(retries, 0);
      async.elapse(const Duration(milliseconds: 1));
      expect(retries, 1);

      async.elapse(const Duration(seconds: 4));
      expect(retries, 2);

      async.elapse(const Duration(seconds: 8));
      expect(retries, 3);

      // Three attempts is the budget: a wallet whose server stays down waits
      // for the next tip or foreground instead of polling forever.
      async.elapse(const Duration(minutes: 5));
      expect(retries, 3);
    });
  });

  test('a failed scan in the background waits for the foreground', () {
    fakeAsync((async) {
      setUpRetries();

      watcher.start();
      foreground.add(false);
      async.flushMicrotasks();

      pushNotification(const SpScanFailed(SilentUnexpected('boom')));
      async.elapse(const Duration(seconds: 8));
      expect(retries, 0);

      foreground.add(true);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));

      expect(retries, 1);
    });
  });

  test('a completed scan cancels the pending retry', () {
    fakeAsync((async) {
      setUpRetries();

      watcher.start();
      pushNotification(const SpScanFailed(SilentUnexpected('boom')));
      async.flushMicrotasks();

      pushNotification(const SpScanCompleted());
      async.elapse(const Duration(seconds: 30));

      expect(retries, 0);
    });
  });

  test('a stopped scan cancels the pending retry', () {
    fakeAsync((async) {
      setUpRetries();

      watcher.start();
      pushNotification(const SpScanFailed(SilentUnexpected('boom')));
      async.flushMicrotasks();

      pushNotification(const SpScanStopped());
      async.elapse(const Duration(seconds: 30));

      expect(retries, 0);
    });
  });

  test('returning to the foreground schedules one retry', () {
    fakeAsync((async) {
      setUpRetries();

      watcher.start();
      foreground.add(false);
      async.flushMicrotasks();
      foreground.add(true);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));

      expect(retries, 1);

      // The retry succeeded, so nothing further is queued.
      async.elapse(const Duration(minutes: 1));
      expect(retries, 1);
    });
  });
}
