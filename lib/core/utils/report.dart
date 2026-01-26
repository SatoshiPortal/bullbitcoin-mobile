import 'package:sentry_flutter/sentry_flutter.dart';

class Report {
  /// Reports an error to Sentry for monitoring and debugging.
  /// Should be called after log.severe() to ensure errors are tracked.
  static Future<void> error(dynamic exception, stackTrace) async {
    if (!Sentry.isEnabled) return;
    Future.microtask(() async {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    });
  }
}
