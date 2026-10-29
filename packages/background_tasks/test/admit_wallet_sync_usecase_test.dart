import 'dart:async';
import 'dart:io';
import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  test(
    'expired admission creates no coordinator or native operation',
    () async {
      var created = false;
      var ran = false;
      final result =
          await AdmitWalletSyncUsecase(
            coordinatorForTimeout: (_) {
              created = true;
              return InMemoryWalletSourceOperationCoordinator();
            },
          ).execute<int>(
            key: const WalletSourceKey('public', 'bitcoin', 'mainnet'),
            deadline: DateTime.utc(2000),
            operation: (_) async {
              ran = true;
              return const Ok(1);
            },
          );
      expect(result, isA<Err<int, WalletTransactionSyncFailure>>());
      expect(created, isFalse);
      expect(ran, isFalse);
    },
  );

  test(
    'contended Bitcoin admission defers and leaves Liquid its turn',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sync-admission-',
      );
      final path = '${directory.path}/coordination.sqlite';
      const key = WalletSourceKey('public', 'bitcoin', 'mainnet');
      final holder = DurableWalletSourceOperationCoordinator(
        databasePath: path,
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      final first = holder.runExclusive(key, (_) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      try {
        final admission = AdmitWalletSyncUsecase(
          coordinatorForTimeout: (timeout) =>
              DurableWalletSourceOperationCoordinator(
                databasePath: path,
                acquisitionTimeout: timeout,
              ),
        );
        var nativeStarted = false;
        final result = await admission.execute<int>(
          key: key,
          deadline: DateTime.now().toUtc().add(
            const Duration(milliseconds: 80),
          ),
          operation: (_) async {
            nativeStarted = true;
            return const Ok(1);
          },
        );
        expect(result, isA<Err<int, WalletTransactionSyncFailure>>());
        expect(nativeStarted, isFalse);
        final liquid = await admission.execute<int>(
          key: const WalletSourceKey('liquid', 'liquid', 'mainnet'),
          deadline: DateTime.now().toUtc().add(const Duration(seconds: 1)),
          operation: (_) async => const Ok(2),
        );
        expect((liquid as Ok<int, WalletTransactionSyncFailure>).value, 2);
      } finally {
        release.complete();
        await first;
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'a timeout inside admitted work keeps its original classification',
    () async {
      final admission = AdmitWalletSyncUsecase(
        coordinatorForTimeout: (_) =>
            InMemoryWalletSourceOperationCoordinator(),
      );
      await expectLater(
        admission.execute<int>(
          key: const WalletSourceKey('public', 'bitcoin', 'mainnet'),
          deadline: DateTime.now().toUtc().add(const Duration(seconds: 1)),
          operation: (_) async => throw TimeoutException('Source work'),
        ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
