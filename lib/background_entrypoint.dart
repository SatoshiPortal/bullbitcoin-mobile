import 'package:background_tasks/background_tasks.dart';

import 'background_bootstrap.dart';

@pragma('vm:entry-point')
void backgroundTasksHandler() {
  runWorkmanagerTaskDispatcher(
    (task) => bootstrapBackgroundRunner(task, clock: Stopwatch()..start()),
  );
}
