import 'package:workmanager/workmanager.dart';

import 'background_task_runner.dart';

typedef BackgroundTaskBootstrap = Future<BackgroundTaskRunner> Function();
typedef BackgroundTaskDispatcher = void Function();

abstract interface class BackgroundTaskScheduler {
  Future<void> initialize(BackgroundTaskDispatcher dispatcher);
  Future<void> cancelByUniqueName(String uniqueName);
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required bool requiresNetwork,
  });
}

final class _WorkmanagerScheduler implements BackgroundTaskScheduler {
  final Workmanager _workmanager;

  const _WorkmanagerScheduler(this._workmanager);

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
  }) => _workmanager.registerPeriodicTask(
    uniqueName,
    taskName,
    frequency: frequency,
    constraints: requiresNetwork
        ? Constraints(networkType: NetworkType.connected)
        : null,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

Future<bool> mapBackgroundTaskResult(
  String taskName,
  BackgroundTaskBootstrap bootstrap,
) async {
  try {
    final result = await (await bootstrap()).run(taskName);
    return !result.shouldRetry;
  } catch (_) {
    return false;
  }
}

void runWorkmanagerTaskDispatcher(BackgroundTaskBootstrap bootstrap) {
  Workmanager().executeTask(
    (taskName, _) => mapBackgroundTaskResult(taskName, bootstrap),
  );
}

/// The shell owns the top-level entry point and supplies a fresh bootstrap for
/// every isolate. No package singleton is shared across WorkManager isolates.
final class BackgroundTaskWorkmanagerAdapter {
  final BackgroundTaskScheduler scheduler;
  BackgroundTaskWorkmanagerAdapter({BackgroundTaskScheduler? scheduler})
    : scheduler = scheduler ?? _WorkmanagerScheduler(Workmanager());

  Future<void> initialize(BackgroundTaskDispatcher dispatcher) =>
      scheduler.initialize(dispatcher);

  Future<bool> execute(
    String taskName,
    BackgroundTaskBootstrap bootstrap,
  ) async {
    return mapBackgroundTaskResult(taskName, bootstrap);
  }

  Future<void> cancelByUniqueName(String uniqueName) =>
      scheduler.cancelByUniqueName(uniqueName);

  Future<void> registerPeriodicTask({
    required String uniqueName,
    required String taskName,
    Duration frequency = const Duration(hours: 1),
    bool requiresNetwork = false,
  }) => scheduler.registerPeriodic(
    uniqueName: uniqueName,
    taskName: taskName,
    frequency: frequency,
    requiresNetwork: requiresNetwork,
  );
}
