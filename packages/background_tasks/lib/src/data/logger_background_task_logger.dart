import 'dart:io' show Directory;

import 'package:bull_logger/bull_logger.dart';

import '../domain/background_task_execution_result.dart';
import '../domain/ports/background_task_logger_port.dart';
import 'workmanager_runner.dart' show BackgroundTaskHandler;

final class LoggerBackgroundTaskLogger implements BackgroundTaskLoggerPort {
  final Logger logger;
  const LoggerBackgroundTaskLogger(this.logger);

  /// Uses the existing process logger when no headless work is admitted.
  static LoggerBackgroundTaskLogger get current =>
      LoggerBackgroundTaskLogger(log);

  static Future<LoggerBackgroundTaskLogger> open(Directory directory) async {
    await initializeLogging(directory: directory, background: true);
    return current;
  }

  BackgroundTaskHandler get prune => () async {
    await logger.prune();
    return const BackgroundTaskExecutionResult.success();
  };

  @override
  void write(BackgroundLogLevel level, String message) {
    switch (level) {
      case BackgroundLogLevel.fine:
        logger.fine(message);
      case BackgroundLogLevel.warning:
        logger.warning(message);
    }
  }

  @override
  Future<void> flush() => logger.flush();
}
