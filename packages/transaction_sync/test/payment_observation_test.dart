import 'package:bull_logger/bull_logger.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/src/engine/payment_observation.dart';

void main() {
  setUp(() async {
    final directory = Directory.systemTemp.createTempSync('observation-log-');
    await initializeLogging(directory: directory);
    addTearDown(() async {
      await log.flush();
      directory.deleteSync(recursive: true);
    });
  });
  test('history programmer errors reach the reporting boundary', () async {
    await expectLater(
      collectPaymentObservation(() => throw StateError('private')),
      throwsStateError,
    );
  });
  test('recording programmer errors reach the reporting boundary', () async {
    await expectLater(
      recordPaymentObservation(
        const Ok<int, TransactionSyncFailure>(1),
        (_) async => throw StateError('private'),
      ),
      throwsStateError,
    );
  });
  test('history failure is missing, not an empty baseline', () async {
    expect(
      await collectPaymentObservation<Set<String>>(
        () => throw const FileSystemException('private'),
      ),
      isNull,
    );
    expect(await collectPaymentObservation(() => <String>{}), isEmpty);
  });
  test(
    'observation failure preserves committed completion and stamp',
    () async {
      final stamp = WalletRevision(
        key: WalletKey(id: 'test', network: BitcoinNetwork.testnet),
        generation: 1,
        revision: 3,
      );
      final completion = const SyncCompletion(
        SyncMode.revealedScripts,
        Duration.zero,
        incomingTxids: {},
      ).committed(stamp);
      for (final callback
          in <Future<Result<void, TransactionSyncFailure>> Function()>[
            () async => const Err(TransactionSyncStorageFailure()),
            () async => throw const FileSystemException('private'),
          ]) {
        final result = Ok<SyncCompletion, TransactionSyncFailure>(completion);
        expect(
          await recordPaymentObservation(result, (_) => callback()),
          same(result),
        );
        expect(completion.revision, same(stamp));
        expect(completion.mode, SyncMode.revealedScripts);
      }
      await log.flush();
      final logs = (await log.readLogs()).join('\n');
      expect(logs, contains('Payment observation failed category=outbox'));
      expect(logs, isNot(contains('private')));
    },
  );
}
