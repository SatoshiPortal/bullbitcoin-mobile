enum BackgroundLogLevel { fine, warning }

/// The persisted diagnostics of a background run.
abstract interface class BackgroundTaskLoggerPort {
  void write(BackgroundLogLevel level, String message);
  Future<void> flush();
}
