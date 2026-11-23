import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';

import '../../../tools/testing/sqlite_test_timing.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final logDirectory = Directory.systemTemp.createTempSync(
    'legacy_storage_test_logs',
  );
  log = Logger.replace(directory: logDirectory);
  await configureSqliteTestTiming();
  await testMain();
}
