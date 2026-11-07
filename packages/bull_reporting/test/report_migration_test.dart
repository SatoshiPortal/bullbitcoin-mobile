import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_reporting/bull_reporting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _Reporter implements LoggerReporter {
  final entered = Completer<void>();
  final captured = Completer<void>();

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) {}

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async {
    expect(message, 'upgrade');
    expect(category, ReportCategory.migration);
    entered.complete();
    await captured.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final fails in [false, true]) {
    test(
      'migration waits for the reporter attempt (failure: $fails)',
      () async {
        SharedPreferences.setMockInitialValues({
          'last_seen_app_version': 'old',
        });
        Report.fromVersion = 'old';
        Report.toVersion = 'new';
        final directory = await Directory.systemTemp.createTemp(
          'report-migration-',
        );
        addTearDown(() async {
          await log.flush();
          await directory.delete(recursive: true);
          Report.fromVersion = null;
          Report.toVersion = null;
        });
        final reporter = _Reporter();
        await initializeLogging(
          directory: directory,
          background: true,
          reporter: reporter,
        );
        final completion = Report.recordMigration();
        final expectation = expectLater(completion, completes);
        await reporter.entered.future;
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('last_seen_app_version'), 'old');
        if (fails) {
          reporter.captured.completeError(StateError('capture failed'));
        } else {
          reporter.captured.complete();
        }
        await expectation;
        // Logger already swallows reporter failures. Preserve that policy.
        expect(prefs.getString('last_seen_app_version'), 'new');
      },
    );
  }
}
