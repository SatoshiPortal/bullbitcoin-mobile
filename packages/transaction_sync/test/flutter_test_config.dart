import 'dart:async';

import '../../../tools/testing/sqlite_test_timing.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await configureSqliteTestTiming();
  await testMain();
}
