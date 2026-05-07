import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/utils/report.dart';
export 'package:bb_mobile/core/utils/report.dart' show ReportCategory;
import 'package:flutter/foundation.dart';
import 'package:logging_colorful/logging_colorful.dart' as dep;
export 'package:logging_colorful/logging_colorful.dart';

// The top-level holder is eagerly seeded with a placeholder anchored at
// `Directory.current` so that any log line emitted before `Bull.initLogs`
// runs (e.g. from a thrown exception during early `WidgetsFlutterBinding`
// init) doesn't hit a `LateInitializationError`. `Bull.initLogs` then
// calls [Logger.replace] which cancels this placeholder's
// `dep.Logger.root.onRecord` subscription before attaching a new one —
// preventing the duplicate-listener leak that occurred when both
// instances stayed subscribed to the same broadcast stream.
Logger log = Logger.replace(directory: Directory.current);

class Logger {
  final Directory dir;
  final dep.LoggerColorful logger;

  static const _logFilename = 'bull_logs.tsv';
  static const _maxLogSizeKb = 100;

  /// Tracks the currently-active Logger so [replace] can cancel its
  /// `dep.Logger.root.onRecord` subscription before installing the
  /// next one. Per-isolate (Dart isolates do not share static state),
  /// so background-task isolates that call `Bull.initLogs` get their
  /// own single-listener lifecycle.
  static Logger? _current;

  IOSink? _sink;
  Future<void> _opChain = Future.value();
  bool _isLogging = false;
  bool _handlingLoggerFailure = false;
  StreamSubscription<dep.LogRecord>? _subscription;

  File get logsFile => File('${dir.path}/$_logFilename');

  Logger._(this.dir, this.logger) {
    dep.Logger.root.level = dep.Level.ALL;

    _subscription = dep.Logger.root.onRecord.listen((record) {
      _isLogging = true;
      try {
        final content = _recordToContent(record);

        // We skip INFO messages in the file and only emit them through the logger/debug output.
        if (record.level != dep.Level.INFO) {
          _queueWrite(
            content.map(_sanitize).join('\t'),
            flush: record.level >= dep.Level.SEVERE,
          );
        }

        // Print the un-sanitized line so ANSI color codes survive to the terminal.
        if (kDebugMode) debugPrint(content.join('\t'));
      } catch (e) {
        if (kDebugMode) debugPrint('[Logger listener failed] $e');
      } finally {
        _isLogging = false;
      }
    });
  }

  /// Builds a new Logger anchored at [directory] and retires the prior
  /// instance (if any) by cancelling its `dep.Logger.root.onRecord`
  /// subscription. Idempotent: safe to call when no prior instance
  /// exists. Callers must reassign the top-level [log] holder to the
  /// returned instance — `Bull.initLogs` is the canonical caller.
  static Logger replace({String name = 'Logger', required Directory directory}) {
    _current?._subscription?.cancel();
    _current?._subscription = null;
    final next = Logger._(
      directory,
      // iOS emulator doesn't support colors –> https://github.com/flutter/flutter/issues/20663
      // We don't want colors in release mode either
      dep.LoggerColorful(name, disabledColors: Platform.isIOS || kReleaseMode),
    );
    _current = next;
    return next;
  }

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

  Future<void> prune() => _enqueue(() async {
    final sizeInKb = (await logsFile.stat()).size ~/ 1000;
    if (sizeInKb <= _maxLogSizeKb) return;

    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    final lines = (await logsFile.readAsLines())
        .where((e) => e.isNotEmpty)
        .toList();
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
    config('Logs deleted');
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
  ///
  /// Optional [category] attaches a `category=<name>` Sentry tag for
  /// crash-cache filtering (e.g. [ReportCategory.migration] for
  /// storage-migration faults); when omitted the tag defaults to
  /// `error`.
  void severe({
    String? message,
    required StackTrace trace,
    required Object error,
    ReportCategory category = ReportCategory.error,
  }) {
    // Guard against reentrant logging: if Report.error() or the broadcast
    // listener throws, runZonedGuarded catches it and calls severe() again
    // while the broadcast stream is still firing — causing a "Cannot fire
    // new event" crash.
    if (_isLogging) {
      _emitDirect(
        level: 'SEVERE',
        message: message ?? error.toString(),
        error: error.toString(),
        trace: trace.toString(),
      );
      return;
    }

    try {
      logger.severe(message ?? error.toString(), error, trace);
    } catch (e) {
      if (kDebugMode) debugPrint('[logger.severe failed] $e');
    }

    try {
      Report.error(
        message: message,
        exception: error,
        stackTrace: trace,
        category: category,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Report.error failed] $e');
    }
  }

  /// Logs non-error high-priority events that reach Sentry (consent-gated).
  /// [error] and [trace] are optional so `shout` can also record info
  /// milestones (install/upgrade, FSS fallback started, feature-flag
  /// flip, etc.). [message] is required — every such event carries a
  /// human-readable label for the Sentry UI and the on-disk TSV log.
  ///
  /// Optional [category] attaches a `category=<name>` Sentry tag for
  /// crash-cache filtering (e.g. [ReportCategory.migration] for
  /// storage-migration faults); when omitted the tag is `none`.
  ///
  /// Returns a `Future<void>` that completes once the underlying
  /// `Report.shout` has finished its Sentry capture. Awaiting it lets
  /// callers serialize before persisting state that depends on the
  /// capture having reached the wire — notably the install/upgrade
  /// milestone, where `Report.commitVersion` advances the persisted
  /// version marker only after the Sentry event is in flight, so a
  /// crash between the two retries the event on the next launch.
  Future<void> shout({
    required String message,
    Object? error,
    StackTrace? trace,
    ReportCategory? category,
  }) async {
    if (_isLogging) {
      _emitDirect(
        level: 'SHOUT',
        message: message,
        error: error?.toString() ?? '',
        trace: trace?.toString() ?? '',
      );
      return;
    }

    try {
      logger.shout(message, error, trace);
    } catch (e) {
      if (kDebugMode) debugPrint('[logger.shout failed] $e');
    }

    try {
      await Report.shout(
        message: message,
        exception: error,
        stackTrace: trace,
        category: category,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Report.shout failed] $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _ensureSinkOpen() {
    _sink ??= logsFile.openWrite(mode: FileMode.append);
  }

  // Bypass the broadcast stream and write a TSV row directly. Used when the
  // listener is already firing (reentrancy) or when the logger itself is in
  // a failure path — both cases where re-entering the dependency logger
  // would risk a "Cannot fire new event" crash.
  //
  // Sanitize per column before joining: `_sanitize` replaces tabs and
  // newlines with spaces, so applying it to the already-joined string
  // would collapse the column-separator tabs and produce a row with a
  // different shape than the normal listener path.
  void _emitDirect({
    required String level,
    required String message,
    String error = '',
    String trace = '',
  }) {
    final time = DateTime.now().toIso8601String();
    final line = [
      time,
      level,
      message,
      error,
      trace,
    ].map(_sanitize).join('\t');
    _queueWrite(line, flush: true);
    if (kDebugMode) debugPrint('[REENTRANT] $line');
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
      _emitDirect(level: 'SEVERE', message: context, error: error.toString());
      if (kDebugMode) debugPrint('[Logger internal] $context: $error');
    } finally {
      _handlingLoggerFailure = false;
    }
  }

  List<String> _recordToContent(dep.LogRecord record) {
    final (:String error, :String trace) = record.stringifyErrorAndTrace();
    return [
      record.time.toIso8601String(),
      record.level.name,
      record.message,
      error,
      trace,
    ];
  }

  String _sanitize(String input) {
    final colors = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'); // ascii colors
    final tabNewLine = RegExp(r'[\t\n\r]');
    return input.replaceAll(tabNewLine, ' ').replaceAll(colors, '');
  }
}
