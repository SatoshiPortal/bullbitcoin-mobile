import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/wallet/data/datasources/lwk_dir_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lwk_dir_guard_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LwkDirGuard', () {
    test(
      'same cache directory: two concurrent callers never run their '
      'bodies concurrently (the exact race behind UpdateOnDifferentStatus)',
      () async {
        final dbPath = '${tempDir.path}/wallet-a';
        var activeCount = 0;
        var maxObservedConcurrent = 0;
        final startOrder = <String>[];
        final finishOrder = <String>[];

        Future<void> caller(String name) => LwkDirGuard.run(dbPath, () async {
          activeCount++;
          maxObservedConcurrent =
              activeCount > maxObservedConcurrent
                  ? activeCount
                  : maxObservedConcurrent;
          startOrder.add(name);
          // Simulate the time lwk.Wallet.init/apply_update spends touching
          // the cache directory: long enough that, absent the guard, the
          // second caller's init would race the first's in-flight update.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          finishOrder.add(name);
          activeCount--;
        });

        // Two "isolate-like" callers (the foreground engine and the
        // workmanager background engine) racing to open the same wollet.
        await Future.wait([caller('foreground'), caller('background')]);

        expect(
          maxObservedConcurrent,
          1,
          reason:
              'both callers touched the same cache directory at once — '
              'this is exactly the race that throws UpdateOnDifferentStatus',
        );
        // Whichever caller went first must fully finish before the other
        // starts: no interleaving of start/finish across callers.
        expect(startOrder[0], finishOrder[0]);
      },
    );

    test(
      'different cache directories: concurrent callers do not block '
      'each other',
      () async {
        final dbPathA = '${tempDir.path}/wallet-a';
        final dbPathB = '${tempDir.path}/wallet-b';
        final bothEnteredCompleter = Completer<void>();
        var entered = 0;

        Future<void> caller(String dbPath) => LwkDirGuard.run(dbPath, () async {
          entered++;
          if (entered == 2) bothEnteredCompleter.complete();
          // If the guard incorrectly serialized unrelated directories, the
          // second caller would never reach this line and the future below
          // would time out, failing the test.
          await bothEnteredCompleter.future.timeout(
            const Duration(seconds: 5),
          );
        });

        await Future.wait([caller(dbPathA), caller(dbPathB)]);

        expect(entered, 2);
      },
    );

    test('releases the lock and cleans up the marker file after the '
        'action completes', () async {
      final dbPath = '${tempDir.path}/wallet-c';

      await LwkDirGuard.run(dbPath, () async => 'ok');

      expect(File('$dbPath.lwkguard').existsSync(), isFalse);

      // A subsequent call must not be blocked by a stale marker.
      final result = await LwkDirGuard.run(
        dbPath,
        () async => 'ok-again',
      ).timeout(const Duration(seconds: 5));
      expect(result, 'ok-again');
    });

    test('releases the lock and cleans up the marker file even when the '
        'action throws', () async {
      final dbPath = '${tempDir.path}/wallet-d';

      await expectLater(
        LwkDirGuard.run(dbPath, () async => throw Exception('boom')),
        throwsException,
      );

      expect(File('$dbPath.lwkguard').existsSync(), isFalse);

      final result = await LwkDirGuard.run(
        dbPath,
        () async => 'recovered',
      ).timeout(const Duration(seconds: 5));
      expect(result, 'recovered');
    });

    test(
      'a marker left by a dead process (different pid) is treated as stale '
      "immediately, not after CrossIsolateDirMarker.maxWait's 45s",
      () async {
        final dbPath = '${tempDir.path}/wallet-e';
        await File('$dbPath.lwkguard').writeAsString(
          jsonEncode({
            'owner': '${pid + 1}-999-123456', // a pid that cannot be ours
            'ts': DateTime.now().toIso8601String(),
          }),
        );

        final stopwatch = Stopwatch()..start();
        final result = await LwkDirGuard.run(
          dbPath,
          () async => 'acquired',
        ).timeout(const Duration(seconds: 5));
        stopwatch.stop();

        expect(result, 'acquired');
        expect(
          stopwatch.elapsed,
          lessThan(const Duration(seconds: 2)),
          reason:
              'a leftover marker from a different pid must not force the '
              'full maxWait/staleAfter wait — it can only be a dead process',
        );
      },
    );
  });
}
