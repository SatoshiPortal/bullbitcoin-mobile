import 'dart:async';
import 'dart:io';

import 'package:background_tasks/src/domain/repositories/background_sync_interval_repository.dart';
import 'package:background_tasks/src/background_task.dart';
import 'package:background_tasks/src/background_task_workmanager_adapter.dart';
import 'package:bull_logger/bull_logger.dart' show log;

/// Admit one background wallet at a time. Native exclusion belongs to the writer.
const backgroundWalletSyncConcurrency = 1;

/// iOS ends a refresh task after about 30 s, Android a worker after 10 min;
/// the budget leaves room for startup and for delivering notifications.
final backgroundRunBudget = Platform.isIOS
    ? const Duration(seconds: 20)
    : const Duration(minutes: 8);

// Serialize OS mutations across settings screens and startup. Initialization is
// outside this queue so an obsolete suspended initialization cannot hold Off.
Future<void> _pendingSchedule = Future.value();
int _scheduleGeneration = 0;

/// Schedules the periodic background tasks at the interval the user chose,
/// and removes the obsolete swap task. Called at startup and whenever the
/// interval changes; UPDATE keeps an unchanged schedule's timing.
///
/// [dispatcher] is the host's headless entry point; [desktopScheduler] runs
/// the work in the app itself where there is no headless engine.
Future<void> applyBackgroundTaskSchedule({
  required BackgroundTaskDispatcher dispatcher,
  required BackgroundSyncIntervalRepository intervals,
  bool enabled = false,
  BackgroundTaskScheduler? scheduler,
  required BackgroundTaskScheduler desktopScheduler,
}) async {
  final generation = ++_scheduleGeneration;
  final mobile = Platform.isAndroid || Platform.isIOS;
  final adapter = BackgroundTaskWorkmanagerAdapter(
    scheduler: scheduler ?? (mobile ? null : desktopScheduler),
  );
  await adapter.initialize(dispatcher);
  final previous = _pendingSchedule;
  final finished = Completer<void>();
  _pendingSchedule = finished.future;
  try {
    await previous;
    if (generation != _scheduleGeneration) return;
    final interval = await intervals.read();
    for (final obsolete in [
      BackgroundTask.swapsSync,
      BackgroundTask.bitcoinSync,
      BackgroundTask.liquidSync,
    ]) {
      await adapter.cancelByUniqueName(obsolete.id);
    }
    if (!enabled) {
      await adapter.cancelByUniqueName(BackgroundTask.walletsSync.id);
      await adapter.cancelByUniqueName(BackgroundTask.logsPrune.id);
      log.config('Background scheduling disabled by rollout gate');
      return;
    }
    final frequency = interval.frequency;
    if (frequency == null) {
      await adapter.cancelByUniqueName(BackgroundTask.walletsSync.id);
    } else {
      await adapter.registerPeriodicTask(
        uniqueName: BackgroundTask.walletsSync.id,
        taskName: BackgroundTask.walletsSync.name,
        requiresNetwork: true,
        frequency: frequency,
        // iOS ignores the frequency: the delay is its "not before" hint. The
        // plugin (workmanager_apple 0.9.11) captures the delay when it first
        // registers its launch handler in a process, so a changed interval is
        // fully applied from the next app start.
        initialDelay: Platform.isIOS ? frequency : null,
      );
    }
    if (mobile) {
      await adapter.registerPeriodicTask(
        uniqueName: BackgroundTask.logsPrune.id,
        taskName: BackgroundTask.logsPrune.name,
        frequency: const Duration(days: 1),
      );
    }
    log.config('Background sync interval applied=${interval.name}');
  } finally {
    finished.complete();
  }
}
