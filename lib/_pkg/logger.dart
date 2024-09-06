import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path_provider/path_provider.dart';

class Logger extends Cubit<List<(String, DateTime)>> {
  Logger() : super([]);

  void log(String message, {bool printToConsole = false}) {
    emit([...state, (message, DateTime.now())]);
    if (printToConsole) print(message);
  }

  void clear() => emit([]);

  void download() async {
    try {
      String logDump;

      final logs = state.reversed.toList();
      logDump = logs.join('\n \n');

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
    } catch (e) {
      log('Error saving logs: $e');
    }
  }
}
