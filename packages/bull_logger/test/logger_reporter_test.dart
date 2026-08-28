import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Reporter implements LoggerReporter {
  final List<String> calls = [];
  final Completer<void> shoutCompletion = Completer<void>();

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) {
    calls.add('error:$message');
  }

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async {
    calls.add('shout:$message');
    await shoutCompletion.future;
  }
}

void main() {
  test('reports errors immediately and awaits shout reporting', () async {
    final directory = await Directory.systemTemp.createTemp('logger-reporter-');
    addTearDown(() async {
      await log.flush();
      await directory.delete(recursive: true);
    });
    final reporter = _Reporter();
    log = Logger.replace(directory: directory, reporter: reporter);

    log.severe(
      message: 'broken',
      error: StateError('failure'),
      trace: StackTrace.current,
    );
    expect(reporter.calls, ['error:broken']);

    final shout = log.shout(message: 'milestone');
    expect(reporter.calls, ['error:broken', 'shout:milestone']);
    var completed = false;
    shout.then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    reporter.shoutCompletion.complete();
    await shout;
    expect(completed, isTrue);
  });
}
