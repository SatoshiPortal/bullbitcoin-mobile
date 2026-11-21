import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  log = Logger.replace(
    directory: Directory.systemTemp.createTempSync('electrum_test_logs'),
  );
  await testMain();
}
