import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Task-specific composition; deliberately never constructs the app locator.
Future<BackgroundTaskRunner> bootstrapBackgroundRunner(
  BackgroundTask task, {
  required Stopwatch clock,
}) async {
  if (!backgroundSyncAvailable) {
    return BackgroundTaskRunner(
      logger: LoggerBackgroundTaskLogger(log),
      handlers: const {},
    );
  }
  final documents = await getApplicationDocumentsDirectory();
  await initializeLogging(directory: documents, background: true);
  final logger = LoggerBackgroundTaskLogger(log);
  return BackgroundTasksLocator.setup(
    task: task,
    logger: logger,
    intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
    tasks: {
      BackgroundTask.logsPrune: (resources) async => () async {
        await log.prune();
        return const BackgroundTaskExecutionResult.success();
      },
      BackgroundTask.walletsSync: (resources) async {
        return setupBackgroundWalletTask(resources, documents, clock);
      },
    },
  );
}
