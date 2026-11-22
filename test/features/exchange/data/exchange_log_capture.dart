import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';

class ExchangeTestReporter implements LoggerReporter {
  final errors = <(String?, String)>[];

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) {
    errors.add((message, exception.toString()));
  }

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async {}
}

Future<({Logger logger, ExchangeTestReporter reporter})>
captureExchangeLogs() async {
  final reporter = ExchangeTestReporter();
  final originalDirectory = log.dir;
  final directory = await Directory.systemTemp.createTemp('bbx-test-logs-');
  final logger = Logger.replace(directory: directory, reporter: reporter);
  log = logger;
  addTearDown(() async {
    await logger.flush();
    log = Logger.replace(directory: originalDirectory);
    await directory.delete(recursive: true);
  });
  return (logger: logger, reporter: reporter);
}
