import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

class Logger extends Cubit<List<(String, DateTime)>> {
  Logger() : super([]);

  void log(String message, {bool printToConsole = false}) {
    emit([...state, (message, DateTime.now())]);
    // ignore: avoid_print
    if (printToConsole) print(message);
  }

  void clear() => emit([]);

  Future<void> shareLog() async {
    try {
      String logDump;

      final logs = state.reversed.toList();
      logDump = logs.join('\n \n');

      final fileName = 'bull-bitcoin-${DateTime.now().toIso8601String()}.log';
      Share.shareXFiles(
        [
          XFile.fromData(
            utf8.encode(logDump),
            mimeType: 'text/plain',
            name: fileName,
          ),
        ],
        // fileNameOverrides: [fileName],
      );

      /*
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final filePath =
            '${externalDir.path}/bull-bitcoin-${DateTime.now().toIso8601String()}.log';
        final fileHandle = File(filePath);
        fileHandle.writeAsString(logDump);
        showToastWidget(
          position: ToastPosition.bottom,
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              color: Colors.grey,
              padding: const EdgeInsets.all(12.0),
              child: Text('Logs saved to $filePath'),
            ),
          ),
          animationCurve: Curves.decelerate,
          duration: const Duration(seconds: 5),
        );
      }
      */
    } catch (e) {
      log('Error saving logs: $e');
    }
  }
}
