import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  for (final durable in [false, true]) {
    test(
      '${durable ? 'durable' : 'memory'} admission expires without releasing the current holder',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'admission-deadline-',
        );
        final WalletSourceOperationCoordinator coordinator = durable
            ? DurableWalletSourceOperationCoordinator(
                databasePath: '${directory.path}/queue.sqlite',
              )
            : InMemoryWalletSourceOperationCoordinator();
        const key = WalletSourceKey('public', 'bitcoin', 'mainnet');
        final entered = Completer<void>(), release = Completer<void>();
        final holder = coordinator.runExclusive(key, (_) async {
          entered.complete();
          await release.future;
        }, timeout: null);
        await entered.future;
        var expiredRan = false, nextRan = false;
        Future<void>? next;
        try {
          final expired = coordinator.runExclusive(
            key,
            (_) async {
              expiredRan = true;
            },
            timeout: null,
            admissionDeadline: DateTime.now().toUtc().add(
              const Duration(milliseconds: 100),
            ),
          );
          await expectLater(
            expired.timeout(const Duration(seconds: 2)),
            throwsA(isA<TimeoutException>()),
          );
          next = coordinator.runExclusive(key, (_) async {
            nextRan = true;
          }, timeout: null);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(expiredRan, isFalse);
          expect(nextRan, isFalse);
        } finally {
          release.complete();
          await holder;
          await next;
          await directory.delete(recursive: true);
        }
        expect(expiredRan, isFalse);
        expect(nextRan, isTrue);
      },
    );
  }
  test(
    'durable deadline includes worker initialization and drains cleanup',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'admission-startup-',
      );
      final path = '${directory.path}/queue.sqlite';
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: path,
        workerInitializationDelay: const Duration(seconds: 5),
      );
      var ran = false;
      try {
        await expectLater(
          coordinator
              .runExclusive(
                const WalletSourceKey('public', 'bitcoin', 'mainnet'),
                (_) async {
                  ran = true;
                },
                timeout: null,
                admissionDeadline: DateTime.now().toUtc().add(
                  const Duration(milliseconds: 100),
                ),
              )
              .timeout(const Duration(seconds: 2)),
          throwsA(isA<TimeoutException>()),
        );
        expect(ran, isFalse);
        await DurableWalletSourceOperationCoordinator(
          databasePath: path,
        ).runExclusive(
          const WalletSourceKey('public', 'bitcoin', 'mainnet'),
          (_) async {},
          admissionDeadline: DateTime.now().toUtc().add(
            const Duration(seconds: 1),
          ),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
