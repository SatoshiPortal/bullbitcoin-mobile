import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

// DONE: add a String encryptionKey to the Logger
// Update the log method to take optional write to file param; if it is true it will write to a file. if an encryptionKey exists, it will encrypt the file.

class Logger extends Cubit<List<(String, DateTime)>> {
  final String? encryptionKey;
  final String filePath;
  Logger._(this.encryptionKey, this.filePath) : super([]);

  static Future<Logger> create(String? encryptionKey) async {
    final dir = await getApplicationDocumentsDirectory();
    // android dir: "/data/user/0/com.bullbitcoin.mobile/app_flutter"
    // ios dir: "/var/mobile/Library/Application Support/com.bullbitcoin.mobile/app_flutter"
    final path = '${dir.path}/bull.log';
    return Logger._(encryptionKey, path);
  }

  void log(String message, {bool toConsole = false}) {
    emit([...state, (message, DateTime.now())]);
    if (toConsole) debugPrint(message);
  }

  Future<void> logToFile(String message) async {
    final logEntry = jsonEncode({
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
    final String content = logEntry;
    if (encryptionKey != null && encryptionKey!.isNotEmpty) {
      // handle file encryption
    }
    final file = File(filePath);
    await file.writeAsString(content, mode: FileMode.append);
  }

  void clear() => emit([]);
}
