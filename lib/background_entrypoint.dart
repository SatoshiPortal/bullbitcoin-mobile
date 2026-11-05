import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/background_bootstrap.dart';
import 'package:bb_mobile/locator.dart';

/// Schedules the periodic background tasks at the interval the user chose.
/// Called at startup and whenever the interval changes.
Future<void> registerBackgroundTasks() => applyBackgroundTaskSchedule(
  dispatcher: backgroundTasksHandler,
  desktopScheduler: _desktopScheduler,
);

/// Desktop has no headless engine: while the app runs, the chosen interval
/// drives the app's own sync of both chains.
final _desktopScheduler = TimerBackgroundTaskScheduler(
  onTick: (_) => locator<SyncCoordinator>().sync(
    only: {SyncKind.bitcoin, SyncKind.liquid},
    trigger: SyncTrigger.scheduled,
  ),
);

@pragma('vm:entry-point')
void backgroundTasksHandler() {
  runWorkmanagerTaskDispatcher(bootstrapBackgroundRunner);
}
