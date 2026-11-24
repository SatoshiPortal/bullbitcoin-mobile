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
    watcher.start();
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

  // Direct add: a testWidgets body runs under fake time, where awaiting a
  // delayed future would need a pump the helper cannot perform.
  void pushNotification(SpNotification notification) => notificationLog.add(
    SpNotifLogLine(time: DateTime.now(), notification: notification),
  );

  test('a tip landing re-runs the sync', () async {
    await emit(const SilentChainTipChanged(900000));

    verify(() => syncUsecase.execute()).called(1);
  });

  test('the same tip repeated syncs only once', () async {
    await emit(const SilentChainTipChanged(900000));
    await emit(const SilentChainTipChanged(900000));

    verify(() => syncUsecase.execute()).called(1);
  });

  test('a new block syncs again', () async {
    await emit(const SilentChainTipChanged(900000));
    await emit(const SilentChainTipChanged(900001));

    verify(() => syncUsecase.execute()).called(2);
  });

  test('other updates never sync', () async {
    await emit(const SilentSetupChanged());
    await emit(SilentBalanceChanged(Sats.fromInt(1000)));

    verifyNever(() => syncUsecase.execute());
  });

  test('a sync failure is swallowed, the watcher stays alive', () async {
    when(() => syncUsecase.execute()).thenAnswer(
      (_) async => const Err<void, SilentFailure>(SilentUnexpected('boom')),
    );

    await emit(const SilentChainTipChanged(900000));
    await emit(const SilentChainTipChanged(900001));

    verify(() => syncUsecase.execute()).called(2);
  });

  test('a tip landing in the background never syncs', () async {
    foreground.add(false);
    await Future<void>.delayed(Duration.zero);

    await emit(const SilentChainTipChanged(900000));

    verifyNever(() => syncUsecase.execute());
  });

  test('dispose stops further syncs', () async {
    await watcher.dispose();

    updates.add(const SilentChainTipChanged(900000));
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => syncUsecase.execute());
  });

  testWidgets('a failed scan is retried, with a growing delay', (tester) async {
    when(() => syncUsecase.execute(resumeOnly: true)).thenAnswer(
      (_) async =>
          const Err<void, SilentFailure>(SilentBackendUnreachable('twice')),
    );

    pushNotification(const SpScanFailed(SilentUnexpected('boom')));
    await tester.pump();
    verifyNever(() => syncUsecase.execute(resumeOnly: true));

    await tester.pump(const Duration(seconds: 2));
    verify(() => syncUsecase.execute(resumeOnly: true)).called(1);

    await tester.pump(const Duration(seconds: 4));
    verify(() => syncUsecase.execute(resumeOnly: true)).called(2);

    await tester.pump(const Duration(seconds: 8));
    verify(() => syncUsecase.execute(resumeOnly: true)).called(3);

    // Three attempts is the budget: a wallet whose server stays down waits
    // for the next tip or foreground instead of polling forever.
    await tester.pump(const Duration(minutes: 5));
    verifyNever(() => syncUsecase.execute(resumeOnly: true));
  });

  testWidgets('a failed scan in the background waits for the foreground', (
    tester,
  ) async {
    foreground.add(false);
    await tester.pump();

    pushNotification(const SpScanFailed(SilentUnexpected('boom')));
    await tester.pump(const Duration(seconds: 8));
    verifyNever(() => syncUsecase.execute(resumeOnly: true));

    foreground.add(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    verify(() => syncUsecase.execute(resumeOnly: true)).called(1);
  });

  testWidgets('a completed scan cancels the pending retry', (tester) async {
    pushNotification(const SpScanFailed(SilentUnexpected('boom')));
    await tester.pump();

    pushNotification(const SpScanCompleted());
    await tester.pump(const Duration(seconds: 30));

    verifyNever(() => syncUsecase.execute(resumeOnly: true));
  });

  testWidgets('returning to the foreground schedules one retry', (
    tester,
  ) async {
    foreground.add(false);
    await tester.pump();
    foreground.add(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    verify(() => syncUsecase.execute(resumeOnly: true)).called(1);

    // The retry succeeded, so nothing further is queued.
    await tester.pump(const Duration(minutes: 1));
    verifyNever(() => syncUsecase.execute(resumeOnly: true));
  });
}
