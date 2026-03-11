import 'package:sentry_flutter/sentry_flutter.dart';

class Report {
  /// Reports an error to Sentry for monitoring and debugging.
  /// Should be called after log.severe() to ensure errors are tracked.
  static Future<void> error({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
  }) async {
    if (!Sentry.isEnabled) return;
    Future.microtask(() async {
      await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        hint: Hint.withMap({
          'message': message ?? exception.runtimeType.toString(),
          'runtimeType': exception.runtimeType.toString(),
        }),
      );
    });
  }
}
