/// The host's headless entry point, a top-level function.
typedef BackgroundTaskDispatcher = void Function();

/// The platform scheduler of periodic headless work.
abstract interface class BackgroundTaskSchedulerPort {
  Future<void> initialize(BackgroundTaskDispatcher dispatcher);
  Future<void> cancelByUniqueName(String uniqueName);
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required bool requiresNetwork,
    Duration? initialDelay,
  });
}
