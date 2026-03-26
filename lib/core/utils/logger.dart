import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/utils/report.dart';
import 'package:flutter/foundation.dart';
import 'package:logging_colorful/logging_colorful.dart' as dep;
export 'package:logging_colorful/logging_colorful.dart';

Logger log = Logger.init();

class Logger {
  final Directory dir;
  final dep.LoggerColorful logger;

  static const _logFilename = 'bull_logs.tsv';
  static const _maxLogSizeKb = 100;

  IOSink? _sink;
  Future<void> _opChain = Future.value();
  bool _isLogging = false;
  bool _handlingLoggerFailure = false;

  File get logsFile => File('${dir.path}/$_logFilename');

  Logger._(this.dir, this.logger) {
    dep.Logger.root.level = dep.Level.ALL;

    dep.Logger.root.onRecord.listen((record) {
      _isLogging = true;
      try {
        final line = _recordToTsvLine(record);

        // We skip INFO messages in the file and only emit them through the logger/debug output.
        if (record.level != dep.Level.INFO) {
          _queueWrite(line, flush: record.level >= dep.Level.SEVERE);
        }

        if (kDebugMode) debugPrint(line);
      } catch (e) {
        if (kDebugMode) debugPrint('[Logger listener failed] $e');
      } finally {
        _isLogging = false;
      }
    });
  }

  Logger.init({String name = 'Logger', Directory? directory})
    : this._(
        directory ?? Directory.current,
        // iOS emulator doesn't support colors –> https://github.com/flutter/flutter/issues/20663
        // We don't want colors in release mode either
        dep.LoggerColorful(
          name,
          disabledColors: Platform.isIOS || kReleaseMode,
        ),
      );

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> ensureLogsExist() async {
    try {
      if (!await logsFile.exists()) {
        await logsFile.create(recursive: true);
        fine('Logs created');
      }
      await _enqueue(() async {
        _ensureSinkOpen();
      });
    } catch (e) {
      _reportLoggerFailure('Logs existence failed', e);
    }
  }

  Future<List<String>> readLogs() async {
    try {
      await flush();
      final logs = await logsFile.readAsString();
      return logs.split('\n').where((e) => e.isNotEmpty).toList();
    } catch (e) {
      _reportLoggerFailure('Failed to read logs', e);
      rethrow;
    }
  }

  Future<int> getSizeInKb() async {
    final stat = await logsFile.stat();
    return stat.size ~/ 1000;
  }

  Future<void> prune() => _enqueue(() async {
        final sizeInKb = (await logsFile.stat()).size ~/ 1000;
        if (sizeInKb <= _maxLogSizeKb) return;

        await _sink?.flush();
        await _sink?.close();
        _sink = null;

        final lines =
            (await logsFile.readAsLines()).where((e) => e.isNotEmpty).toList();
        final linesToDelete = lines.length ~/ 2;
        final logsToKeep = lines.sublist(linesToDelete);

        await logsFile.writeAsString(
          logsToKeep.isEmpty ? '' : '${logsToKeep.join('\n')}\n',
        );
        _ensureSinkOpen();

        final newSizeInKb = (await logsFile.stat()).size ~/ 1000;
        fine('Logs pruned from $sizeInKb kB to $newSizeInKb kB');
      });

  Future<void> flush() => _enqueue(() async {
        await _sink?.flush();
      });

  Future<void> deleteLogs() async {
    await _enqueue(() async {
      await _sink?.flush();
      await _sink?.close();
      _sink = null;
      await logsFile.writeAsString('');
      _ensureSinkOpen();
    });
    shout('Logs deleted');
  }

  Future<void> migration({
    required dep.Level level,
    required String message,
    Map<String, dynamic>? context,
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    final now = DateTime.now().toIso8601String();
    final content = <String>[
      now,
      level.name,
      message,
      context?.toString() ?? '',
      exception?.toString() ?? '',
      stackTrace?.toString() ?? '',
    ];
    final line = content.map(_sanitize).join('\t');
    _queueWrite(line);
  }

  // ---------------------------------------------------------------------------
  // Log level methods
  // ---------------------------------------------------------------------------

  /// Logs information messages that are part of the normal operation of the app.
  /// These messages are typically written to file only and not kept in memory.
  /// Use for recording general app flow and user actions.
  void info(Object? message, {Object? error, StackTrace? trace}) {
    logger.info(message, error, trace);
  }

  /// Logs static configuration information at startup or during major configuration changes.
  /// Use for logging app settings, environment details, or significant state changes.
  void config(Object? message, {Object? error, StackTrace? trace}) {
    logger.config(message, error, trace);
  }

  /// Logs basic tracing information for debugging.
  /// Use for high-level flow tracking during development and troubleshooting.
  void fine(Object? message, {Object? error, StackTrace? trace}) {
    logger.fine(message, error, trace);
  }

  /// Logs detailed tracing information.
  /// Use for more granular debugging information than fine(), such as loop iterations or method entry/exit.
  void finer(Object? message, {Object? error, StackTrace? trace}) {
    logger.finer(message, error, trace);
  }

  /// Logs highly detailed tracing information.
  /// Use for the most detailed level of debugging, such as variable values within loops.
  void finest(Object? message, {Object? error, StackTrace? trace}) {
    logger.finest(message, error, trace);
  }

  /// Logs potentially harmful situations that don't prevent the app from working.
  /// Use for recoverable errors or unexpected but handled conditions.
  void warning(Object? message, {Object? error, StackTrace? trace}) {
    logger.warning(message, error, trace);
  }

  /// Logs serious errors that may prevent parts of the app from working correctly.
  /// Use for unrecoverable errors that require immediate attention.
  /// [trace] is required to ensure proper error tracking in Sentry.
  void severe({
    String? message,
    required StackTrace trace,
    required Object error,
  }) {
    // Guard against reentrant logging: if Report.error() or the broadcast
    // listener throws, runZonedGuarded catches it and calls severe() again
    // while the broadcast stream is still firing — causing a "Cannot fire
    // new event" crash.
    if (_isLogging) {
      // Bypass the broadcast stream entirely — write directly to file.
      final time = DateTime.now().toIso8601String();
      final line = _sanitize(
        [
          time,
          'SEVERE',
          message ?? error.toString(),
          error.toString(),
          trace.toString(),
        ].join('\t'),
      );
      _queueWrite(line, flush: true);
      if (kDebugMode) debugPrint('[REENTRANT] $line');
      return;
    }

    try {
      logger.severe(message ?? error.toString(), error, trace);
    } catch (e) {
      if (kDebugMode) debugPrint('[logger.severe failed] $e');
    }

    try {
      Report.error(message: message, exception: error, stackTrace: trace);
    } catch (e) {
      if (kDebugMode) debugPrint('[Report.error failed] $e');
    }
  }

  /// Logs critical errors that could crash the app or make it unusable.
  /// Use for the most severe errors that require immediate intervention.
  void shout(Object? message, {Object? error, StackTrace? trace}) {
    if (_isLogging) {
      final time = DateTime.now().toIso8601String();
      final line = _sanitize(
        [
          time,
          'SHOUT',
          message?.toString() ?? '',
          error?.toString() ?? '',
          trace?.toString() ?? '',
        ].join('\t'),
      );
      _queueWrite(line, flush: true);
      if (kDebugMode) debugPrint('[REENTRANT] $line');
      return;
    }

    try {
      logger.shout(message, error, trace);
    } catch (e) {
      if (kDebugMode) debugPrint('[logger.shout failed] $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _ensureSinkOpen() {
    _sink ??= logsFile.openWrite(mode: FileMode.append);
  }

  // Serializes all sink operations (writes, flushes, prune, delete) to avoid
  // "StreamSink is bound to a stream" errors from concurrent flush/write.
  // Note: This is safe because Dart is single-threaded — writeln() completes
  // atomically before yielding. If background isolates ever need to log,
  // they should send messages to the main isolate via SendPort/ReceivePort
  // rather than writing to the sink directly.
  Future<void> _enqueue(Future<void> Function() operation) {
    _opChain = _opChain.catchError((_) {}).then((_) async {
      try {
        await operation();
      } catch (e) {
        if (kDebugMode) debugPrint('[Logger op failed] $e');
      }
    });
    return _opChain;
  }

  void _queueWrite(String log, {bool flush = false}) {
    unawaited(
      _enqueue(() async {
        _ensureSinkOpen();
        _sink!.writeln(log);
        if (flush) await _sink!.flush();
      }),
    );
  }

  /// Logs internal logger failures without calling severe() (which would
  /// risk recursion if the logger itself is broken).
  void _reportLoggerFailure(String context, Object error) {
    if (_handlingLoggerFailure) {
      if (kDebugMode) debugPrint('[Logger internal] $context: $error');
      return;
    }

    _handlingLoggerFailure = true;
    try {
      final time = DateTime.now().toIso8601String();
      final line = _sanitize(
        [time, 'SEVERE', context, error.toString()].join('\t'),
      );
      _queueWrite(line, flush: true);
      if (kDebugMode) debugPrint('[Logger internal] $context: $error');
    } finally {
      _handlingLoggerFailure = false;
    }
  }

  String _recordToTsvLine(dep.LogRecord record) {
    final content = <String>[
      record.time.toIso8601String(),
      record.level.name,
      record.message,
    ];
    final (:String error, :String trace) = record.stringifyErrorAndTrace();
    content.addAll([error, trace]);
    return content.map(_sanitize).join('\t');
  }

  String _sanitize(String input) {
    final colors = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'); // ascii colors
    final tabNewLine = RegExp(r'[\t\n\r]');
    return input.replaceAll(tabNewLine, ' ').replaceAll(colors, '');
  }

  static String redactAddressOrTxId(String? value) {
    if (value == null || value.isEmpty) return value ?? '';
    if (value.length <= 6) return value;
    return '${value.substring(0, 3)}...${value.substring(value.length - 3)}';
  }
}
