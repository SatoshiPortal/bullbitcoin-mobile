import 'dart:async';

import 'background_task.dart';
import 'background_task_runner.dart';

/// Resources acquired by one selected headless task, never the app locator. Register cleanup immediately after acquisition, before the next await.
final class BackgroundTaskResources {
  final List<FutureOr<void> Function()> _cleanup = [];
  bool _closed = false;

  void onClose(FutureOr<void> Function() dispose) {
    if (_closed) throw StateError('Background resources already closed');
    _cleanup.add(dispose);
  }

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

typedef BackgroundTaskSetup =
    Future<BackgroundTaskHandler> Function(BackgroundTaskResources resources);

/// Selects one setup before constructing anything. Factories must open only their task's capabilities and register each owned resource for cleanup. Wallet factories must check the app schema before opening its database.
final class BackgroundTasksLocator {
  static Future<BackgroundTaskRunner> setup({
    required BackgroundTask task,
    required BackgroundTaskLogger logger,
    required Map<BackgroundTask, BackgroundTaskSetup> tasks,
  }) async {
    final resources = BackgroundTaskResources();
    try {
      final factory = tasks[task];
      final handlers = <BackgroundTask, BackgroundTaskHandler>{};
      if (factory != null && task != BackgroundTask.swapsSync) {
        handlers[task] = await factory(resources);
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
}
