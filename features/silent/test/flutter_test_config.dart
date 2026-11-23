import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final directory = Directory.systemTemp.createTempSync('silent_test_logs');
  log = Logger.replace(directory: directory);
  await testMain();
}
