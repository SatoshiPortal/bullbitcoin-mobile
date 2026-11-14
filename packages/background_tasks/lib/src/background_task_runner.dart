import 'background_task_logger.dart';
import 'domain/background_task.dart';
import 'domain/background_task_execution_result.dart';

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
