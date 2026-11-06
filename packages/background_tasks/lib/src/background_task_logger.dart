import 'package:bull_logger/bull_logger.dart';

enum BackgroundLogLevel { fine, warning }

abstract interface class BackgroundTaskLogger {
  void write(BackgroundLogLevel level, String message);
  Future<void> flush();
}

final class LoggerBackgroundTaskLogger implements BackgroundTaskLogger {
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
