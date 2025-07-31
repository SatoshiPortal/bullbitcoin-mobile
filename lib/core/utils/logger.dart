import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging_colorful/logging_colorful.dart' as dep;

export 'package:logging_colorful/logging_colorful.dart';

// DONE: add a String encryptionKey to the Logger
// Update the log method to take optional write to file param; if it is true it will write to a file. if an encryptionKey exists, it will encrypt the file.

Logger log = Logger.init();

class Logger {
  final session = <String>[];
  final String? encryptionKey;
  final Directory dir;
  final dep.LoggerColorful logger;

  static const _migrationFilename = 'bull_migration_logs.tsv';
  static const _sessionFilename = 'bull_session_logs.tsv';
  File get sessionLogs => File('${dir.path}/$_sessionFilename');
  File get migrationLogs => File('${dir.path}/$_migrationFilename');

  Logger._(this.encryptionKey, this.dir, this.logger) {
    dep.Logger.root.level = dep.Level.ALL;

    dep.Logger.root.onRecord.listen((record) {
      final time = record.time.toIso8601String();
      final content = [time, record.level.name, record.message];

      String error = '';
      String trace = '';
      // standard record.error is a list containing [exception, stack trace, zone] default is [null, null, null]
      if (record.error is List && (record.error! as List).isNotEmpty) {
        final firstElement = (record.error! as List).first;
        if (firstElement != null) error = firstElement.toString();
        try {
          final secondElement = (record.error! as List).elementAt(1);
          if (secondElement != null) trace = secondElement.toString();
        } catch (_) {}
      }
      content.add(error);
      content.add(trace);

      final sanitizedContent = _sanitizeContent(content);
      final tsvLine = sanitizedContent.join('\t');

      // We don't want to keep the info session in memory, they should be written to file
      if (record.level != dep.Level.INFO) session.add(tsvLine);

      if (kDebugMode) {
        // remove timestamp and errors
        final debug = content.sublist(1, 3);
        debugPrint(debug.join('\t'));
      }
    });
  }

  Logger.init({
    String? encryptionKey,
    String name = 'Logger',
    Directory? directory,
  }) : this._(
         encryptionKey,
         directory ?? Directory.current,
         // iOS emulator doesn't support colors –> https://github.com/flutter/flutter/issues/20663
         // We don't want colors in release mode either
         dep.LoggerColorful(
           name,
           disabledColors: Platform.isIOS || kReleaseMode,
         ),
       );

  Future<void> dumpSessionToFile() async {
    await sessionLogs.writeAsString(session.join('\n'));
  }

  List<String> _sanitizeContent(List<String> content) {
    final colors = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'); // ascii colors
    final tabNewLine = RegExp(r'[\t\n]'); // no tabs or newlines
    final sanitizedContent =
        content
            .map((e) => e.replaceAll(tabNewLine, ' ').replaceAll(colors, ''))
            .toList();
    return sanitizedContent;
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
  void severe(Object? message, {Object? error, StackTrace? trace}) {
    logger.severe(message, error, trace);
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

    final sanitizedContent = _sanitizeContent(content);
    final tsvLine = sanitizedContent.join('\t');
    await appendToMigrationFile(tsvLine);
  }

  Future<void> appendToMigrationFile(String message) async {
    await migrationLogs.writeAsString('$message\n', mode: FileMode.append);
  }
}
