import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../tools/testing/sqlite_test_timing.dart';

void main() {
  test(
    'SQLite busy_timeout really waits 300 ms between connections',
    () {
      final directory = Directory.systemTemp.createTempSync('sqlite-busy-');
      final path = '${directory.path}/lock.sqlite';
      final holder = sqlite3.open(path);
      final contender = sqlite3.open(path);
      try {
        holder.execute('BEGIN IMMEDIATE');
        contender.execute('PRAGMA busy_timeout = 300');
        final watch = Stopwatch()..start();
        expect(
          () => contender.execute('BEGIN IMMEDIATE'),
          throwsA(
            isA<SqliteException>().having(
              (e) => e.resultCode,
              'SQLITE_BUSY',
              5,
            ),
          ),
        );
        watch.stop();
        expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(300));
      } finally {
        contender.dispose();
        holder.dispose();
        directory.deleteSync(recursive: true);
      }
    },
    skip: sqliteTimingSkipReason,
  );
}
