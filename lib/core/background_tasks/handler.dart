import 'package:workmanager/workmanager.dart';

/// Removes schedules persisted by releases that enabled background execution.
Future<void> cancelLegacyBackgroundTasks() async {
  await Workmanager().initialize(backgroundTasksHandler);
  await Workmanager().cancelAll();
}

@pragma('vm:entry-point')
void backgroundTasksHandler() {
  Workmanager().executeTask((task, inputData) async {
    return await tasksHandler(task);
  });
}

/// Answers a schedule left by an older release, and does nothing else.
///
/// Background execution is off: the app cancels these schedules on every foreground start. A schedule can still fire before that first start, and the local databases must not be opened then: only the foreground app migrates them, encrypts them and resets them (`LocalData`), and a background connection racing any of those would corrupt or resurrect data. So this opens no database, reads no key and builds no locator. Reporting success stops the scheduler from retrying.
Future<bool> tasksHandler(String task) async => true;
