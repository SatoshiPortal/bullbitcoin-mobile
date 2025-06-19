import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging_colorful/logging_colorful.dart' as dep;
import 'package:path_provider/path_provider.dart';
export 'package:logging_colorful/logging_colorful.dart';

// DONE: add a String encryptionKey to the Logger
// Update the log method to take optional write to file param; if it is true it will write to a file. if an encryptionKey exists, it will encrypt the file.

late Logger log;

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

      if (record.error != null) content.add(record.error.toString());
      if (record.stackTrace != null) content.add(record.stackTrace.toString());

      final tsvLine = _sanitizeContent(content).join('\t');

      // We don't want to keep the info session in memory, they should be written to file
      if (record.level != dep.Level.INFO) session.add(tsvLine);

      if (kDebugMode) {
        content.removeAt(0); // remove the time
        debugPrint(content.join('\t'));
      }
    });
  }

  static Future<Logger> init({
    String? encryptionKey,
    String name = 'Logger',
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    // android dir: "/data/user/0/com.bullbitcoin.mobile/app_flutter"
    // ios dir: "/var/mobile/Library/Application Support/com.bullbitcoin.mobile/app_flutter"

    return Logger._(
      encryptionKey,
      dir,
      // iOS emulator doesn't support colors –> https://github.com/flutter/flutter/issues/20663
      // We don't want colors in release mode either
      dep.LoggerColorful(name, disabledColors: Platform.isIOS || kReleaseMode),
    );
  }

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

  void info(Object? message, {Object? error, StackTrace? trace}) {
    logger.info(message, error, trace);
  }

  void config(Object? message, {Object? error, StackTrace? trace}) {
    logger.config(message, error, trace);
  }

  void fine(Object? message, {Object? error, StackTrace? trace}) {
    logger.fine(message, error, trace);
  }

  void finer(Object? message, {Object? error, StackTrace? trace}) {
    logger.finer(message, error, trace);
  }

  void finest(Object? message, {Object? error, StackTrace? trace}) {
    logger.finest(message, error, trace);
  }

  void warning(Object? message, {Object? error, StackTrace? trace}) {
    logger.warning(message, error, trace);
  }

  void severe(Object? message, {Object? error, StackTrace? trace}) {
    logger.severe(message, error, trace);
  }

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
    if (context != null) content.add(context.toString());
    if (exception != null) content.add(exception.toString());
    if (stackTrace != null) content.add(stackTrace.toString());

    final sanitizedContent = _sanitizeContent(content);
    final tsvLine = sanitizedContent.join('\t');
    await appendToMigrationFile(tsvLine);
  }

  Future<void> appendToMigrationFile(String message) async {
    await migrationLogs.writeAsString('$message\n', mode: FileMode.append);
  }
}
