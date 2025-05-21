abstract class LogRepository {
  Future<void> logTrace({
    required String message,
    required String logger,
    Map<String, dynamic>? context,
  });
  Future<void> logDebug({
    required String message,
    required String logger,
    Map<String, dynamic>? context,
  });
  Future<void> logInfo({
    required String message,
    required String logger,
    Map<String, dynamic>? context,
  });
  Future<void> logError({
    required String message,
    required String logger,
    required Object exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  });
  Future<void> truncateLogs(DateTime from, DateTime until);
  Future<void> clearLogs();
}
