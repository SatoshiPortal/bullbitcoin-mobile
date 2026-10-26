import 'dart:io';

import 'package:bb_mobile/tor_runtime_adapters.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Reporter implements LoggerReporter {
  final List<String> calls = [];

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) => calls.add('error');

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async => calls.add('shout');
}

void main() {
  test(
    'Tor support diagnostics persist without invoking the reporter',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tor_log_routes_',
      );
      final reporter = _Reporter();
      final logger = Logger.replace(directory: directory, reporter: reporter);
      addTearDown(() async {
        await logger.flush();
        await directory.delete(recursive: true);
      });
      final torLogger = createTorLogger(logger);
      torLogger
        ..info('tor_native_console_marker')
        ..fine('tor_native_milestone_marker')
        ..config('tor_native_config_marker')
        ..warning('tor_native_failure_marker');
      await logger.flush();
      final messages = (await logger.readLogs()).map(
        (line) => line.split('\t')[2],
      );
      expect(
        messages,
        containsAll([
          'tor_native_milestone_marker',
          'tor_native_config_marker',
          'tor_native_failure_marker',
        ]),
      );
      expect(messages, isNot(contains('tor_native_console_marker')));
      expect(reporter.calls, isEmpty);
    },
  );
}
