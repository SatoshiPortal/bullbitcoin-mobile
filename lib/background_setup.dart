import 'package:background_tasks/background_tasks.dart';
import 'background_bootstrap.dart';
import 'background_entrypoint.dart';

final _desktopScheduler = TimerBackgroundTaskScheduler(
  onTick: (taskName) async {
    await mapBackgroundTaskResult(
      taskName,
      (task) => bootstrapBackgroundRunner(task, clock: Stopwatch()..start()),
    );
  },
);

Future<void> configureBackgroundTasks() => applyBackgroundTaskSchedule(
  dispatcher: backgroundTasksHandler,
  intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
  desktopScheduler: _desktopScheduler,
  enabled: backgroundSyncAvailable,
);
