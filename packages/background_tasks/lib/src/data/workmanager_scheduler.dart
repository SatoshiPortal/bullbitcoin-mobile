import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart' show log;
import 'package:workmanager/workmanager.dart';

import '../domain/background_task.dart';
import '../domain/ports/background_task_scheduler_port.dart';
import '../domain/repositories/background_sync_interval_repository.dart';

final class WorkmanagerScheduler implements BackgroundTaskSchedulerPort {
  final Workmanager _workmanager;

  WorkmanagerScheduler() : _workmanager = Workmanager();

  @override
  Future<void> initialize(BackgroundTaskDispatcher dispatcher) =>
      _workmanager.initialize(dispatcher);

  @override
  Future<void> cancelByUniqueName(String uniqueName) =>
      _workmanager.cancelByUniqueName(uniqueName);

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required bool requiresNetwork,
    Duration? initialDelay,
  }) => _workmanager.registerPeriodicTask(
    uniqueName,
    taskName,
    frequency: frequency,
    initialDelay: initialDelay,
    constraints: requiresNetwork
        ? Constraints(networkType: NetworkType.connected)
        : null,
    // UPDATE applies a new interval to work already scheduled on the device;
    // KEEP would leave it on the interval it was first registered with.
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

// Serialize OS mutations across settings screens and startup. Initialization is
// outside this queue so an obsolete suspended initialization cannot hold Off.
Future<void> _pendingSchedule = Future.value();
int _scheduleGeneration = 0;

/// Schedules the periodic background tasks at the interval the user chose,
/// and removes the obsolete ones. Called at startup and whenever the
/// interval changes; UPDATE keeps an unchanged schedule's timing.
///
/// [dispatcher] is the host's headless entry point. Without an injected
/// [scheduler], only Android and iOS schedule: desktop has no WorkManager
/// and never had a schedule to cancel.
Future<void> applyBackgroundTaskSchedule({
  required BackgroundTaskDispatcher dispatcher,
  required BackgroundSyncIntervalRepository intervals,
  bool enabled = false,
  BackgroundTaskSchedulerPort? scheduler,
}) async {
  final generation = ++_scheduleGeneration;
  final mobile = Platform.isAndroid || Platform.isIOS;
  if (scheduler == null && !mobile) return;
  final platform = scheduler ?? WorkmanagerScheduler();
  await platform.initialize(dispatcher);
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
      await platform.cancelByUniqueName(obsolete.id);
    }
    if (!enabled) {
      await platform.cancelByUniqueName(BackgroundTask.walletsSync.id);
      await platform.cancelByUniqueName(BackgroundTask.logsPrune.id);
      log.config('Background scheduling disabled by rollout gate');
      return;
    }
    final frequency = interval.frequency;
    if (frequency == null) {
      await platform.cancelByUniqueName(BackgroundTask.walletsSync.id);
    } else {
      await platform.registerPeriodic(
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
      await platform.registerPeriodic(
        uniqueName: BackgroundTask.logsPrune.id,
        taskName: BackgroundTask.logsPrune.name,
        requiresNetwork: false,
        frequency: const Duration(days: 1),
      );
    }
    log.config('Background sync interval applied=${interval.name}');
  } finally {
    finished.complete();
  }
}
