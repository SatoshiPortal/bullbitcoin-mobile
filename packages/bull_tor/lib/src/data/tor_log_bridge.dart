import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:bull_sdk/onion.dart' as onion;

import 'tor_logger.dart';

/// Routes native diagnostics to the host logger with bounded persistent output.
final class TorLogBridge {
  final TorLogger _log;
  final int _maxRecords;
  final int _maxBytes;
  final Duration Function() _elapsed;
  StreamSubscription<onion.TorLogRecord>? _subscription;
  Duration _windowStart = Duration.zero;
  int _records = 0;
  int _bytes = 0;
  int _dropped = 0;
  int _repeated = 0;
  String? _previous;
  onion.TorLogLevel? _previousLevel;
  Future<void>? _closing;
  bool _closed = false;

  /// At most 64 native lines and 16 KiB per one-minute budget window, plus one bounded summary; warnings reserve part of that budget.
  TorLogBridge(
    this._log, {
    int maxRecords = 64,
    int maxBytes = 16 * 1024,
    Duration Function()? elapsed,
  }) : _maxRecords = maxRecords,
       _maxBytes = maxBytes,
       _elapsed = elapsed ?? _monotonicClock() {
    if (maxRecords < 1 || maxBytes < 1) {
      throw ArgumentError('Native log budgets must be positive');
    }
  }

  void start(Stream<onion.TorLogRecord> records) {
    if (_subscription != null || _closed) {
      throw StateError('Native log bridge can only start once');
    }
    _subscription = records.listen(
      _onRecord,
      onError: (Object error, StackTrace trace) {
        if (error is Error) Error.throwWithStackTrace(error, trace);
        // Foreign exceptions can contain destinations; keep only fixed metadata.
        _onRecord(
          const onion.TorLogRecord(
            level: onion.TorLogLevel.warn,
            target: 'onion::capture',
            message: 'stream_failed',
          ),
        );
      },
      onDone: _flushSummary,
    );
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    await _subscription?.cancel();
    _flushSummary();
  }

  void _onRecord(onion.TorLogRecord record) {
    if (_closed) return;
    final now = _elapsed();
    if (now - _windowStart >= const Duration(minutes: 1)) {
      _flushSummary();
      _windowStart = now;
      _records = 0;
      _bytes = 0;
      _previous = null;
      _previousLevel = null;
    }
    final line = '[${record.target}] ${record.message}';
    if (line == _previous && record.level == _previousLevel) {
      _repeated++;
      return;
    }
    _previous = line;
    _previousLevel = record.level;
    final warning = switch (record.level) {
      onion.TorLogLevel.error || onion.TorLogLevel.warn => true,
      onion.TorLogLevel.info || onion.TorLogLevel.debug => false,
    };
    final persistent =
        warning ||
        (record.level == onion.TorLogLevel.info &&
            (const ['onion', 'tor_hsclient', 'tor_circmgr']).any(
              (target) =>
                  record.target == target ||
                  record.target.startsWith('$target::'),
            ));
    if (!persistent) {
      _log.info(line);
      return;
    }
    final bytes = utf8.encode(line).length;
    final recordLimit = warning
        ? _maxRecords
        : _maxRecords - math.min(16, _maxRecords ~/ 4);
    final byteLimit = warning
        ? _maxBytes
        : _maxBytes - math.min(8192, _maxBytes ~/ 4);
    if (_records >= recordLimit || _bytes + bytes > byteLimit) {
      _dropped++;
      return;
    }
    _records++;
    _bytes += bytes;
    if (warning) {
      _log.warning(line);
    } else {
      _log.fine(line);
    }
  }

  void _flushSummary() {
    if (_dropped == 0 && _repeated == 0) return;
    _log.fine('tor_native summary dropped=$_dropped repeated=$_repeated');
    _dropped = 0;
    _repeated = 0;
  }

  static Duration Function() _monotonicClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }
}
