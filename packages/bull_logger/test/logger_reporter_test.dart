import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';
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
  test('persists support levels and reports only severe and shout', () async {
    final directory = await Directory.systemTemp.createTemp('logger-levels-');
    addTearDown(() async {
      await log.flush();
      await directory.delete(recursive: true);
    });
    final reporter = _Reporter();
    reporter.shoutCompletion.complete();
    log = Logger.replace(directory: directory, reporter: reporter);

    log.info('route-info');
    log.fine('route-fine');
    log.finer('route-finer');
    log.finest('route-finest');
    log.config('route-config');
    log.warning('route-warning');
    expect(reporter.calls, isEmpty);

    log.severe(
      message: 'route-severe',
      error: StateError('sentinel-failure'),
      trace: StackTrace.current,
    );
    await log.shout(message: 'route-shout');

    final rows = (await log.readLogs()).map((line) => line.split('\t'));
    final routes = {for (final row in rows) row[2]: row[1]};
    expect(routes, {
      'route-fine': 'FINE',
      'route-finer': 'FINER',
      'route-finest': 'FINEST',
      'route-config': 'CONFIG',
      'route-warning': 'WARNING',
      'route-severe': 'SEVERE',
      'route-shout': 'SHOUT',
    });
    expect(reporter.calls, ['error:route-severe', 'shout:route-shout']);
  });

  test(
    'severe and shout remain local when no reporter is configured',
    () async {
      final directory = await Directory.systemTemp.createTemp('logger-local-');
      addTearDown(() async {
        await log.flush();
        await directory.delete(recursive: true);
      });
      log = Logger.replace(directory: directory);

      log.severe(
        message: 'local-severe',
        error: StateError('sentinel-failure'),
        trace: StackTrace.current,
      );
      await log.shout(message: 'local-shout');

      final messages = (await log.readLogs()).map(
        (line) => line.split('\t')[2],
      );
      expect(messages, containsAll(['local-severe', 'local-shout']));
    },
  );

  test(
    'reentrant severe and shout persist without invoking the reporter',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'logger-reentrant-',
      );
      final previousDebugPrint = debugPrint;
      addTearDown(() async {
        debugPrint = previousDebugPrint;
        await log.flush();
        await directory.delete(recursive: true);
      });
      final reporter = _Reporter();
      log = Logger.replace(directory: directory, reporter: reporter);
      var reentered = false;
      debugPrint = (message, {wrapWidth}) {
        if (reentered || message?.contains('reentrant-trigger') != true) return;
        reentered = true;
        log.severe(
          message: 'reentrant-severe',
          error: StateError('sentinel-failure'),
          trace: StackTrace.current,
        );
        unawaited(log.shout(message: 'reentrant-shout'));
      };

      log.info('reentrant-trigger');
      await Future<void>.delayed(Duration.zero);

      expect(reentered, isTrue);
      expect(reporter.calls, isEmpty);
      final messages = (await log.readLogs()).map(
        (line) => line.split('\t')[2],
      );
      expect(messages, containsAll(['reentrant-severe', 'reentrant-shout']));
      expect(messages, isNot(contains('reentrant-trigger')));
    },
  );

  test(
    'recoverable diagnostics persist safe cause types without reporting',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'logger-recoverable-',
      );
      addTearDown(() async {
        await log.flush();
        await directory.delete(recursive: true);
      });
      final reporter = _Reporter();
      log = Logger.replace(directory: directory, reporter: reporter);
      log.warning('credential unavailable', error: FormatException);
      log.info('credential retry', error: FormatException);
      log.fine('credential recovered');
      final rows = (await log.readLogs())
          .map((line) => line.split('\t'))
          .toList();
      expect(rows.map((row) => row[1]), ['WARNING', 'FINE']);
      expect(rows.first[3], contains('FormatException'));
      expect(reporter.calls, isEmpty);
    },
  );

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
