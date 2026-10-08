import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';

final class _RecordingState {
  final List<String> messages = [];
  Object? errorValue;
  StackTrace? traceValue;
}

final class _RecordingSink implements LogSink {
  final _RecordingState _state;
  final String _prefix;

  _RecordingSink() : _state = _RecordingState(), _prefix = '';

  _RecordingSink._(this._state, this._prefix);

  List<String> get messages => _state.messages;
  Object? get errorValue => _state.errorValue;
  StackTrace? get traceValue => _state.traceValue;

  String _message(String message) => '$_prefix$message';

  @override
  void fine(String message, {Object? error, StackTrace? trace}) {
    messages.add('fine:${_message(message)}');
    _state.errorValue = error;
    _state.traceValue = trace;
  }

  @override
  void info(String message, {Object? error, StackTrace? trace}) {
    messages.add('info:${_message(message)}');
    _state.errorValue = error;
    _state.traceValue = trace;
  }

  @override
  void warning(String message, {Object? error, StackTrace? trace}) {
    messages.add('warning:${_message(message)}');
    _state.errorValue = error;
    _state.traceValue = trace;
  }

  @override
  void error(String message, {Object? error, StackTrace? trace}) {
    messages.add('error:${_message(message)}');
    _state.errorValue = error;
    _state.traceValue = trace;
  }

  @override
  LogSink scoped(String scope) {
    final trimmed = scope.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(scope);
    return _RecordingSink._(_state, '$_prefix[$trimmed] ');
  }
}

final class _CapturingReporter implements LoggerReporter {
  String? message;
  Object? exception;
  StackTrace? stackTrace;

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) {
    this.message = message;
    this.exception = exception;
    this.stackTrace = stackTrace;
  }

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async {}
}

void main() {
  test('scoped sinks prefix ordinary levels and preserve optional data', () {
    final sink = _RecordingSink();
    final error = StateError('broken');
    final trace = StackTrace.current;
    final scoped = sink.scoped('wallet');

    scoped.fine('started');
    scoped.info('loaded');
    scoped.warning('slow', error: error, trace: trace);

    expect(sink.messages, [
      'fine:[wallet] started',
      'info:[wallet] loaded',
      'warning:[wallet] slow',
    ]);
    expect(sink.errorValue, error);
    expect(sink.traceValue, trace);
  });

  test('scoped sinks prefix error calls and compose predictably', () {
    final sink = _RecordingSink();
    final error = StateError('broken');
    final trace = StackTrace.current;

    sink
        .scoped('outer')
        .scoped('inner')
        .error('failed', error: error, trace: trace);

    expect(sink.messages, ['error:[outer] [inner] failed']);
    expect(sink.errorValue, error);
    expect(sink.traceValue, trace);
  });

  test('scopes reject blank names', () {
    final sink = _RecordingSink();

    expect(() => sink.scoped('  '), throwsArgumentError);
    expect(() => sink.scoped('outer').scoped('\n\t'), throwsArgumentError);
  });

  test('Logger.error reports supplied values and provides fallbacks', () async {
    final directory = await Directory.systemTemp.createTemp('logger-sink-');
    final reporter = _CapturingReporter();
    addTearDown(() async {
      await log.flush();
      await directory.delete(recursive: true);
    });
    log = Logger.replace(directory: directory, reporter: reporter);

    final trace = StackTrace.current;
    final error = StateError('broken');
    log.error('explicit', error: error, trace: trace);
    expect(reporter.message, 'explicit');
    expect(reporter.exception, error);
    expect(reporter.stackTrace, trace);

    log.scoped('recoverbull').error('scoped', error: error, trace: trace);
    expect(reporter.message, '[recoverbull] scoped');
    expect(reporter.exception, error);
    expect(reporter.stackTrace, trace);

    log.error('fallback');
    expect(reporter.message, 'fallback');
    expect(reporter.exception, 'fallback');
    expect(reporter.stackTrace, isNotNull);
  });

  test('sanitizes secrets and only preserves labeled failure types', () async {
    final directory = await Directory.systemTemp.createTemp('logger-sanitize-');
    addTearDown(() async {
      await log.flush();
      await directory.delete(recursive: true);
    });
    log = Logger.replace(directory: directory);

    const typeName = 'RecoverBullTemporarilyUnavailableFailure';
    const letterOnlyToken = 'AbcdefGhijklMnopqrStuvwxYzabcdef';
    const uppercaseSecret = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef';
    const base64Secret = 'QmFzZTY0U2VjcmV0VG9rZW4xMjM0NTY3ODkw';
    const longTypeName = 'RecoverBullTemporarilyUnavailableFailure';
    const hex = '0123456789abcdef0123456789abcdef';
    const base64 = 'QmFzZTY0IHNlY3JldCBibG9iIHdpdGggMTIzNDU2Nzg=';
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const token = 'token=super-secret-token-value';
    log.warning(typeName);
    log.warning(letterOnlyToken);
    log.warning('cause=$uppercaseSecret');
    log.warning('failure_type=$base64Secret');
    log.warning('failure_type=$longTypeName');
    log.warning(longTypeName);
    log.warning('failure_type=');
    log.warning(hex);
    log.warning(base64);
    log.warning(mnemonic);
    log.warning(token);

    final lines = await log.readLogs();
    expect(lines[0], isNot(contains(typeName)));
    expect(lines[1], isNot(contains(letterOnlyToken)));
    expect(lines[2], isNot(contains(uppercaseSecret)));
    expect(lines[3], isNot(contains(base64Secret)));
    expect(lines[4], contains('failure_type=$longTypeName'));
    expect(lines[5], isNot(contains(longTypeName)));
    expect(lines[6], contains('failure_type='));
    expect(lines[6], isNot(contains('[REDACTED]')));
    expect(lines[7], isNot(contains(hex)));
    expect(lines[8], isNot(contains(base64)));
    expect(lines[9], isNot(contains(mnemonic)));
    expect(lines[10], isNot(contains('super-secret-token-value')));
  });
}
