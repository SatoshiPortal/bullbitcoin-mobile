import 'dart:async';

import 'background_task_workmanager_adapter.dart';

/// Desktop scheduler: runs a task on a timer while the app is running. There
/// is no headless engine there, so [onTick] runs the work in the app itself.
final class TimerBackgroundTaskScheduler implements BackgroundTaskScheduler {
  final Future<void> Function(String taskName) onTick;
  final Map<String, Timer> _timers = {};
  final Set<String> _running = {};

  TimerBackgroundTaskScheduler({required this.onTick});

  @override
  Future<void> initialize(BackgroundTaskDispatcher dispatcher) async {}

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    _timers.remove(uniqueName)?.cancel();
  }

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required bool requiresNetwork,
    Duration? initialDelay,
  }) async {
    _timers.remove(uniqueName)?.cancel();
    _timers[uniqueName] = Timer.periodic(frequency, (_) async {
      // A slow tick never overlaps the next one, and missed ticks after a
      // suspend do not pile up: Timer.periodic does not catch up.
      if (!_running.add(uniqueName)) return;
      try {
        await onTick(taskName);
      } catch (_) {
        // The next tick retries; the task logs its own failures.
      } finally {
        _running.remove(uniqueName);
      }
    });
  }
}
