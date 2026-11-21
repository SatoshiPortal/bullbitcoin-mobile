import 'package:primitives/primitives.dart';

import 'dart:async';

import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:flutter/widgets.dart';

import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/watchers/sp_tip_watcher.dart';
import 'package:bb_mobile/features/sp/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchSpUpdatesUsecase extends Mock
    implements WatchSpUpdatesUsecase {}

class _MockWatchSpNotificationLogUsecase extends Mock
    implements WatchSpNotificationLogUsecase {}

class _MockSyncSpWalletUsecase extends Mock implements SyncSpWalletUsecase {}

void main() {
  late StreamController<SpUpdate> updates;
  late _MockWatchSpUpdatesUsecase watchUsecase;
  late _MockSyncSpWalletUsecase syncUsecase;
  late SpTipWatcher watcher;
  late StreamController<AppLifecycleState> lifecycle;
  late StreamController<SpNotifLogLine> notificationLog;

  setUp(() {
    updates = StreamController<SpUpdate>.broadcast();
    watchUsecase = _MockWatchSpUpdatesUsecase();
    syncUsecase = _MockSyncSpWalletUsecase();
    when(() => watchUsecase.execute()).thenAnswer((_) => updates.stream);
    when(() => syncUsecase.execute())
        .thenAnswer((_) async => const Ok<void, SpFailure>(null));
    lifecycle = StreamController<AppLifecycleState>.broadcast();
    notificationLog = StreamController<SpNotifLogLine>.broadcast();
    final notifications = _MockWatchSpNotificationLogUsecase();
    when(notifications.execute)
        .thenReturn((log: [], updates: notificationLog.stream));
    watcher = SpTipWatcher(
      watchSpNotificationLogUsecase: notifications,
      lifecycleStates: lifecycle.stream,
      initiallyForeground: true,
      watchSpUpdatesUsecase: watchUsecase,
      syncSpWalletUsecase: syncUsecase,
    );
  });

  tearDown(() async {
    await watcher.dispose();
    await updates.close();
    await lifecycle.close();
    await notificationLog.close();
  });

  Future<void> emit(SpUpdate update) async {
    watcher.start();
    updates.add(update);
    await Future<void>.delayed(Duration.zero);
  }

  test('a tip landing re-runs the sync', () async {
    await emit(const SpChainTipChanged(900000));

    verify(() => syncUsecase.execute()).called(1);
  });

  test('the same tip repeated syncs only once', () async {
    await emit(const SpChainTipChanged(900000));
    await emit(const SpChainTipChanged(900000));

    verify(() => syncUsecase.execute()).called(1);
  });

  test('a new block syncs again', () async {
    await emit(const SpChainTipChanged(900000));
    await emit(const SpChainTipChanged(900001));

    verify(() => syncUsecase.execute()).called(2);
  });

  test('other updates never sync', () async {
    await emit(const SpSetupChanged());
    await emit(SpBalanceChanged(Sats.fromInt(1000)));

    verifyNever(() => syncUsecase.execute());
  });

  test('a sync failure is swallowed, the watcher stays alive', () async {
    when(
      () => syncUsecase.execute(),
    ).thenAnswer((_) async => const Err<void, SpFailure>(SpUnexpected('boom')));

    await emit(const SpChainTipChanged(900000));
    await emit(const SpChainTipChanged(900001));

    verify(() => syncUsecase.execute()).called(2);
  });

  testWidgets('failed scan retries only after returning to the foreground', (
    tester,
  ) async {
    watcher.start();
    when(() => syncUsecase.execute(resumeOnly: true))
        .thenAnswer((_) async => const Ok<void, SpFailure>(null));
    lifecycle.add(AppLifecycleState.paused);
    notificationLog.add(
      SpNotifLogLine(
        time: DateTime.now(),
        notification: const SpScanFailed(SpUnexpected()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    verifyNever(() => syncUsecase.execute(resumeOnly: true));

    lifecycle.add(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    verify(() => syncUsecase.execute(resumeOnly: true)).called(1);
  });

  test('dispose stops further syncs', () async {
    watcher.start();
    await watcher.dispose();

    updates.add(const SpChainTipChanged(900000));
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => syncUsecase.execute());
  });
}
