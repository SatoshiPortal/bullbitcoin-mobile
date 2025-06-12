import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging_colorful/logging_colorful.dart' as dep;
import 'package:path_provider/path_provider.dart';

// DONE: add a String encryptionKey to the Logger
// Update the log method to take optional write to file param; if it is true it will write to a file. if an encryptionKey exists, it will encrypt the file.

late Logger log;

class Logger {
  final String? encryptionKey;
  final String logPath;
  final dep.LoggerColorful logger;
  Logger._(this.encryptionKey, this.logPath, this.logger);

  static Future<Logger> init({
    String? encryptionKey,
    String name = 'Logger',
  }) async {
    dep.Logger.root.level = dep.Level.ALL;
    dep.Logger.root.onRecord.listen((record) {
      String message = '${record.level.name}\t${record.message}';
      if (record.stackTrace != null) message += '\t${record.stackTrace}';
      debugPrint(message);
    });

    final dir = await getApplicationDocumentsDirectory();
    final logPath = '${dir.path}/bull.txt';
    // android dir: "/data/user/0/com.bullbitcoin.mobile/app_flutter"
    // ios dir: "/var/mobile/Library/Application Support/com.bullbitcoin.mobile/app_flutter"

    return Logger._(
      encryptionKey,
      logPath,
      // iOS emulator doesn't support colors –> https://github.com/flutter/flutter/issues/20663
      // We don't want colors in release mode either
      dep.LoggerColorful(name, disabledColors: Platform.isIOS || kReleaseMode),
    );
  }

  Future<void> logToFile(String message) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final tsvContent = '$now\t$message\n';
    if (encryptionKey != null && encryptionKey!.isNotEmpty) {
      // handle file encryption
    }
    final file = File(logPath);
    await file.writeAsString(tsvContent, mode: FileMode.append);
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
}
