import 'package:bb_mobile/core/utils/report.dart';
import 'package:bull_logger/bull_logger.dart';

final class ReportLoggerAdapter implements LoggerReporter {
  const ReportLoggerAdapter();

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) {
    Report.error(
      message: message,
      exception: exception,
      stackTrace: stackTrace,
      category: category,
    );
  }

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) => Report.shout(
    message: message,
    exception: exception,
    stackTrace: stackTrace,
    category: category,
  );
}
