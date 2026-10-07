import 'package:bull_logger/bull_logger.dart';

final class TestLogEntry {
  final String level;
  final String message;
  final Object? error;
  final StackTrace? trace;
  final String scope;

  const TestLogEntry({
    required this.level,
    required this.message,
    required this.scope,
    this.error,
    this.trace,
  });
}

class TestLogSink implements LogSink {
  final List<TestLogEntry>? _entries;
  final String _scope;

  const TestLogSink() : _entries = null, _scope = '';

  TestLogSink.recording() : _entries = [], _scope = '';

  TestLogSink._(this._entries, this._scope);

  List<TestLogEntry> get entries => List.unmodifiable(_entries ?? const []);

  @override
  void fine(String message, {Object? error, StackTrace? trace}) =>
      _record('fine', message, error, trace);

  @override
  void info(String message, {Object? error, StackTrace? trace}) =>
      _record('info', message, error, trace);

  @override
  void warning(String message, {Object? error, StackTrace? trace}) =>
      _record('warning', message, error, trace);

  @override
  void error(String message, {Object? error, StackTrace? trace}) =>
      _record('error', message, error, trace);

  @override
  TestLogSink scoped(String scope) {
    final trimmed = scope.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(scope, 'scope', 'must not be empty');
    }
    final entries = _entries;
    return entries == null
        ? TestLogSink()
        : TestLogSink._(entries, '$_scope[$trimmed]');
  }

  void _record(String level, String message, Object? error, StackTrace? trace) {
    _entries?.add(
      TestLogEntry(
        level: level,
        message: message,
        error: error,
        trace: trace,
        scope: _scope,
      ),
    );
  }
}
