import 'package:bull_logger/bull_logger.dart';

import 'background_task.dart';
import 'background_task_execution_result.dart';

abstract interface class BackgroundTaskLogger {
  void info(String message);
  void warning(String message);
  Future<void> flush();
}

final class LoggerBackgroundTaskLogger implements BackgroundTaskLogger {
  final Logger logger;
  const LoggerBackgroundTaskLogger(this.logger);

  @override
  void info(String message) => logger.info(message);

  @override
  void warning(String message) => logger.warning(message);

  @override
  Future<void> flush() => logger.flush();
}

typedef BackgroundTaskHandler =
    Future<BackgroundTaskExecutionResult> Function();

final class BackgroundTaskRunner {
  final BackgroundTaskLogger logger;
  final Map<BackgroundTask, BackgroundTaskHandler> handlers;
  final Future<void> Function()? onFinished;

  const BackgroundTaskRunner({
    required this.logger,
    required this.handlers,
    this.onFinished,
  });

  /// Builds the compatibility set used by the shell. Swaps are deliberately a
  /// successful no-op for tasks persisted by older releases.
  factory BackgroundTaskRunner.compatibility({
    required BackgroundTaskLogger logger,
    required BackgroundTaskHandler bitcoinSync,
    required BackgroundTaskHandler liquidSync,
    required Future<void> Function() pruneLogs,
    Future<void> Function()? onFinished,
  }) => BackgroundTaskRunner(
    logger: logger,
    handlers: {
      BackgroundTask.bitcoinSync: bitcoinSync,
      BackgroundTask.liquidSync: liquidSync,
      BackgroundTask.logsPrune: () async {
        await pruneLogs();
        return const BackgroundTaskExecutionResult.success();
      },
      BackgroundTask.swapsSync: () async =>
          const BackgroundTaskExecutionResult.success(),
    },
    onFinished: onFinished,
  );

  Future<BackgroundTaskExecutionResult> run(String taskName) async {
    late BackgroundTaskExecutionResult result;
    try {
      final task = BackgroundTask.resolve(taskName);
      if (task == null) {
        _warning('Unknown background task');
        result = const BackgroundTaskExecutionResult.permanentFailure();
      } else {
        final handler = handlers[task];
        if (handler == null) {
          result = const BackgroundTaskExecutionResult.success();
        } else {
          result = await handler();
          if (result.status == BackgroundTaskExecutionStatus.permanentFailure) {
            _warning('Background task permanently failed');
          }
        }
      }
    } catch (_) {
      _warning('Background task failed unexpectedly');
      result = const BackgroundTaskExecutionResult.retry();
    }

    var cleanupFailed = false;
    try {
      await logger.flush();
    } catch (_) {
      cleanupFailed = true;
    }
    try {
      await onFinished?.call();
    } catch (_) {
      cleanupFailed = true;
    }

    if (cleanupFailed && !result.shouldRetry) {
      return const BackgroundTaskExecutionResult.retry();
    }
    return result;
  }

  void _warning(String message) {
    try {
      logger.warning(message);
    } catch (_) {}
  }
}
