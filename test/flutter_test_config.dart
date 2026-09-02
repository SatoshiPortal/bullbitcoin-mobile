import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';

/// Auto-loaded by `flutter test`. Runs once per test binary process,
/// before any test in `test/` executes.
///
/// SP cubit tests intentionally exercise error paths (e.g.
/// `SpCubit.prepare: insufficient funds`, `SpCubit.load: wallet error`)
/// which the global logger would otherwise append to `bull_logs.tsv`.
/// The default logger is anchored at `Directory.current`, i.e. the repo
/// checkout, so a test run would write a log file into the working tree.
/// Redirect it to a fresh system-temp dir, never in the checkout, so no suite
/// touches the tree. One dir per process: test binaries run in parallel and
/// would otherwise interleave lines in a shared file.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final logDir = Directory.systemTemp.createTempSync('bull_mobile_test_logs');
  log = Logger.replace(directory: logDir);
  await testMain();
}
