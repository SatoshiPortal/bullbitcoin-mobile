import 'package:background_tasks/background_tasks.dart';
import 'background_entrypoint.dart';

Future<void> configureBackgroundTasks() => applyBackgroundTaskSchedule(
  dispatcher: backgroundTasksHandler,
  intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
  enabled: backgroundSyncAvailable,
);
