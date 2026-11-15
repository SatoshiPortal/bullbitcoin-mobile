import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart' show log;
import 'package:workmanager/workmanager.dart';

import '../domain/background_sync_interval.dart';
import '../domain/background_task.dart';
import '../domain/background_task_execution_result.dart';
import '../domain/ports/background_task_logger_port.dart';
import '../domain/repositories/background_sync_interval_repository.dart';

/// iOS ends a refresh task after about 30 s, Android a worker after 10 min;
/// the budget leaves room for startup and for delivering notifications.
final backgroundRunBudget = Platform.isIOS
    ? const Duration(seconds: 20)
    : const Duration(minutes: 8);

typedef BackgroundTaskHandler =
    Future<BackgroundTaskExecutionResult> Function();
typedef BackgroundTaskSetup =
    Future<BackgroundTaskHandler> Function(BackgroundTaskResources resources);
typedef BackgroundTaskBootstrap =
    Future<BackgroundTaskRunner> Function(BackgroundTask task);

/// The shell owns the top-level entry point and supplies a fresh bootstrap for
/// every isolate. No package singleton is shared across WorkManager isolates.
void runWorkmanagerTaskDispatcher(BackgroundTaskBootstrap bootstrap) {
  Workmanager().executeTask(
    (taskName, _) => mapBackgroundTaskResult(taskName, bootstrap),
  );
}

/// What WorkManager receives: false asks it to retry the task later.
Future<bool> mapBackgroundTaskResult(
  String taskName,
  BackgroundTaskBootstrap bootstrap,
) async {
  final task = BackgroundTask.resolve(taskName);
  // Acknowledge unknown and obsolete work without opening wallet resources.
  if (task == null || task == BackgroundTask.swapsSync) return true;
  try {
    final result = await (await bootstrap(task)).run(task);
    return !result.shouldRetry;
  } catch (error) {
    log.warning('Background startup failed type=${error.runtimeType}');
    await log.flush();
    return false;
  }
}

/// Resources acquired by one selected headless task, never the app locator.
/// Register cleanup immediately after acquisition, before the next await.
final class BackgroundTaskResources {
  final List<FutureOr<void> Function()> _cleanup = [];
  bool _closed = false;

  void onClose(FutureOr<void> Function() dispose) {
    if (_closed) throw StateError('Background resources already closed');
    _cleanup.add(dispose);
  }

  /// Closes in reverse order of acquisition, attempting every close.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    Object? firstFailure;
    StackTrace? firstStack;
    for (final dispose in _cleanup.reversed) {
      try {
        await dispose();
      } catch (error, stack) {
        // Cleanup must continue even for a programming error, then rethrow it.
        firstFailure ??= error;
        firstStack ??= stack;
      }
    }
    _cleanup.clear();
    if (firstFailure != null && firstStack != null) {
      Error.throwWithStackTrace(firstFailure, firstStack);
    }
  }
}

final class BackgroundTaskRunner {
  final BackgroundTaskLoggerPort logger;
  final Map<BackgroundTask, BackgroundTaskHandler> handlers;
  final Future<void> Function()? onFinished;

  const BackgroundTaskRunner({
    required this.logger,
    required this.handlers,
    this.onFinished,
  });

  /// Builds only the selected task, before anything else is opened. A setup
  /// opens only its task's capabilities and registers each owned resource
  /// for cleanup; a wallet setup checks the app schema before opening its
  /// database. A partial startup closes what it opened, in reverse order.
  static Future<BackgroundTaskRunner> forTask({
    required BackgroundTask task,
    required BackgroundTaskLoggerPort logger,
    required BackgroundSyncIntervalRepository intervals,
    required Map<BackgroundTask, BackgroundTaskSetup> tasks,
  }) async {
    final resources = BackgroundTaskResources();
    try {
      final setup = tasks[task];
      final handlers = <BackgroundTask, BackgroundTaskHandler>{};
      final optedOut =
          task == BackgroundTask.walletsSync &&
          await intervals.read() == BackgroundSyncInterval.off;
      if (optedOut) {
        logger.write(
          BackgroundLogLevel.fine,
          'Background admission stopped: category=opt_out',
        );
      }
      if (setup != null && task != BackgroundTask.swapsSync && !optedOut) {
        handlers[task] = await setup(resources);
      }
      return BackgroundTaskRunner(
        logger: logger,
        handlers: handlers,
        onFinished: resources.close,
      );
    } catch (error, stack) {
      try {
        await resources.close();
      } catch (_) {
        // Preserve the original startup failure after attempting every close.
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<BackgroundTaskExecutionResult> run(BackgroundTask task) async {
    late BackgroundTaskExecutionResult result;
    final stopwatch = Stopwatch()..start();
    try {
      _fine('Background task ${task.name} started');
      final handler = handlers[task];
      result = handler == null
          ? const BackgroundTaskExecutionResult.success()
          : await handler();
      if (result.status == BackgroundTaskExecutionStatus.permanentFailure) {
        _warning('Background task permanently failed');
      }
    } catch (error) {
      _warning('Background task failed unexpectedly type=${error.runtimeType}');
      result = const BackgroundTaskExecutionResult.retry();
    }
    _fine(
      'Background task ${task.name} finished status=${result.status.name} '
      'elapsed_ms=${stopwatch.elapsedMilliseconds}',
    );

    // A failed flush or dispose does not undo what the task did: the next run
    // opens everything again, so the task's own result stands.
    try {
      await logger.flush();
    } catch (error) {
      _warning('Background task log flush failed type=${error.runtimeType}');
    }
    try {
      await onFinished?.call();
    } catch (error) {
      _warning('Background task cleanup failed type=${error.runtimeType}');
    }
    return result;
  }

  void _fine(String message) {
    try {
      logger.write(BackgroundLogLevel.fine, message);
    } catch (_) {}
  }

  void _warning(String message) {
    try {
      logger.write(BackgroundLogLevel.warning, message);
    } catch (_) {}
  }
}
