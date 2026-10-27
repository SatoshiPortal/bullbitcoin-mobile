import 'package:bull_logger/bull_logger.dart';

import 'background_task.dart';
import 'background_task_execution_result.dart';

abstract interface class BackgroundTaskLogger {
  void fine(String message);
  void warning(String message);
  Future<void> flush();
}

final class LoggerBackgroundTaskLogger implements BackgroundTaskLogger {
  final Logger logger;
  const LoggerBackgroundTaskLogger(this.logger);

  @override
  void fine(String message) => logger.fine(message);

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
    final stopwatch = Stopwatch()..start();
    BackgroundTask? task;
    try {
      task = BackgroundTask.resolve(taskName);
      if (task == null) {
        _warning('Unknown background task');
        result = const BackgroundTaskExecutionResult.permanentFailure();
      } else {
        _fine('Background task ${task.name} started');
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
    if (task != null) {
      // Before the flush, so the line reaches disk before the OS reclaims the
      // isolate.
      _fine(
        'Background task ${task.name} finished status=${result.status.name} '
        'elapsed_ms=${stopwatch.elapsedMilliseconds}',
      );
    }

    // A failed flush or dispose does not undo what the task did: the next run
    // opens everything again, so the task's own result stands.
    try {
      await logger.flush();
    } catch (_) {
      _warning('Background task log flush failed');
    }
    try {
      await onFinished?.call();
    } catch (_) {
      _warning('Background task cleanup failed');
    }
    return result;
  }

  void _fine(String message) {
    try {
      logger.fine(message);
    } catch (_) {}
  }

  void _warning(String message) {
    try {
      logger.warning(message);
    } catch (_) {}
  }
}
