import 'package:bull_logger/bull_logger.dart';

import '../domain/ports/background_task_logger_port.dart';

final class LoggerBackgroundTaskLogger implements BackgroundTaskLoggerPort {
  final Logger logger;
  const LoggerBackgroundTaskLogger(this.logger);

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
