import 'dart:async';

import 'package:bull_logger/bull_logger.dart' show log;
import 'package:primitives/primitives.dart';

import 'background_rollout.dart';
import 'data/shared_preferences_background_sync_interval_repository.dart';
import 'data/workmanager_scheduler.dart';
import 'domain/background_sync_interval.dart';
import 'domain/background_tasks_failure.dart';
import 'domain/ports/background_task_scheduler_port.dart';
import 'domain/repositories/background_sync_interval_repository.dart';

/// Foreground control of the persisted interval and its platform schedule.
final class BackgroundSchedule {
  final BackgroundSyncIntervalRepository _intervals;
  final Future<void> Function() _schedule;

  Future<void> _pendingWrite = Future.value();
  int _generation = 0;

  BackgroundSchedule._(this._intervals, this._schedule);

  factory BackgroundSchedule.open({
    required BackgroundTaskDispatcher dispatcher,
    BackgroundSyncIntervalRepository intervals =
        const SharedPreferencesBackgroundSyncIntervalRepository(),
    BackgroundTaskSchedulerPort? scheduler,
    bool? enabled,
  }) => BackgroundSchedule._(
    intervals,
    () => applyBackgroundTaskSchedule(
      dispatcher: dispatcher,
      intervals: intervals,
      enabled: enabled ?? backgroundSyncAvailable,
      scheduler: scheduler,
    ),
  );

  Future<void> apply() => _schedule();

  Future<Result<BackgroundSyncInterval, BackgroundTasksFailure>>
  interval() async {
    try {
      while (true) {
        final generation = _generation;
        // Platform scheduling must not block reads.
        await _pendingWrite;
        final interval = await _intervals.read();
        if (generation == _generation) return Ok(interval);
      }
    } on Exception {
      log.warning('Background interval read failed');
      return const Err(BackgroundSyncIntervalFailure());
    }
  }

  Future<Result<void, BackgroundTasksFailure>> setInterval(
    BackgroundSyncInterval value,
  ) async {
    final generation = ++_generation;
    final previous = _pendingWrite;
    final finished = Completer<void>();
    _pendingWrite = finished.future;
    try {
      await previous;
      if (generation != _generation) return const Ok(null);
      final result = await _intervals.write(value);
      if (result is Err) {
        log.warning('Background interval persistence failed');
        return const Err(BackgroundSyncIntervalFailure());
      }
      log.config('Background interval saved=${value.name}');
    } finally {
      // Platform scheduling must not delay persistence of a newer opt-out.
      finished.complete();
    }
    if (generation != _generation) return const Ok(null);
    try {
      await apply();
      log.config('Background schedule applied interval=${value.name}');
      return const Ok(null);
    } on Exception {
      log.warning('Background schedule update failed');
      return const Err(BackgroundSyncIntervalFailure());
    }
  }
}
