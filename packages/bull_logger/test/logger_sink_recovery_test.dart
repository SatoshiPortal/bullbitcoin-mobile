import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory previousDirectory;
  late bool previousBackground;

  setUp(() {
    previousDirectory = log.dir;
    previousBackground = log.filename == 'bull_background_logs.tsv';
  });

  tearDown(() {
    log = Logger.replace(
      directory: previousDirectory,
      background: previousBackground,
    );
  });

  test(
    'a vanished log directory drops the line without a pending error',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'bull-logger-gone-',
      );
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      log = Logger.replace(directory: directory);

      // The open runs asynchronously: deleting first makes it fail after the
      // caller that logged the line has already returned.
      directory.deleteSync(recursive: true);
      log.fine('written while the log directory is absent');
      await log.flush();

      expect(log.logsFile.existsSync(), isFalse);

      directory.createSync(recursive: true);
      log.fine('written once the log directory returns');
      await log.flush();

      expect(
        await log.logsFile.readAsString(),
        contains('written once the log directory returns'),
      );
    },
  );
}
