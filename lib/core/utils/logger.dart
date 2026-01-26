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
  Future<void>? _currentWrite;

  static const _logFilename = 'bull_logs.tsv';

  File get logsFile => File('${dir.path}/$_logFilename');

  Future<List<String>> readLogs() async {
    try {
      final logs = await logsFile.readAsString();
      return logs.split('\n').where((e) => e.isNotEmpty).toList();
    } catch (e) {
      severe('Failed to read logs: $e', trace: StackTrace.current);
      rethrow;
    }
  }

  Future<int> getSizeInKb() async {
    final logsBytes = await logsFile.readAsBytes();
    return logsBytes.length ~/ 1000;
  }

  Future<void> prune() async {
    final logsSizeInKb = await getSizeInKb();
    if (logsSizeInKb <= 100) return;

    final logs = await readLogs();
    final linesToDelete = logs.length ~/ 2;
    final logsToKeep = logs.sublist(linesToDelete);
    await logsFile.writeAsString(logsToKeep.join('\n'));
    final logsSizeInKbAfter = await getSizeInKb();
    log.fine('Logs pruned from $logsSizeInKb kB to $logsSizeInKbAfter kB');
  }

  Logger._(this.dir, this.logger) {
    dep.Logger.root.level = dep.Level.ALL;

    dep.Logger.root.onRecord.listen((record) {
      final time = record.time.toIso8601String();
      final content = [time, record.level.name, record.message];

      final (:String error, :String trace) = record.stringifyErrorAndTrace();
      content.addAll([error, trace]);

      final sanitizedContent = content.map((e) => _sanitize(e)).toList();
      final tsvLine = sanitizedContent.join('\t');

      // We don't want to keep the info session in memory, they should be written to file
      if (record.level != dep.Level.INFO) _queueWrite(tsvLine);

      if (kDebugMode) {
        // remove timestamp and errors
        final debug = content.sublist(1, 3);
        debugPrint(debug.join('\t'));
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

  Future<void> ensureLogsExist() async {
    try {
      if (await logsFile.exists()) return;

      await logsFile.create(recursive: true);
      fine('Logs created');
    } catch (e) {
      severe('Logs existence: $e', trace: StackTrace.current);
    }
  }

  void _queueWrite(String log) {
    final write = () async {
      await _currentWrite;
      await logsFile.writeAsString('$log\n', mode: FileMode.append);
    }();

    _currentWrite = write;
  }

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
  void severe(Object message, {Object? error, required StackTrace trace}) {
    logger.severe(message, error, trace);
    Report.error(message, trace);
  }

  /// Logs critical errors that could crash the app or make it unusable.
  /// Use for the most severe errors that require immediate intervention.
  void shout(Object? message, {Object? error, StackTrace? trace}) {
    logger.shout(message, error, trace);
  }

  Future<void> migration({
    required dep.Level level,
    required String message,
    Map<String, dynamic>? context,
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    final now = DateTime.now().toIso8601String();
    final content = [now, level.name, message];
    content.add(context?.toString() ?? '');
    content.add(exception?.toString() ?? '');
    content.add(stackTrace?.toString() ?? '');

    final sanitizedContent = content.map((e) => logger.sanitize(e)).toList();
    final tsvLine = sanitizedContent.join('\t');
    _queueWrite(tsvLine);
  }

  Future<void> deleteLogs() async {
    await logsFile.writeAsString('');
    log.shout('Logs deleted');
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
