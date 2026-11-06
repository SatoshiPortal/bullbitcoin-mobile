import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  for (final changeGeneration in [false, true]) {
    test(
      'reader stamp re-enables repair failure (generation=$changeGeneration)',
      () async {
        final database = sqlite3.openInMemory();
        final queue = SqliteWalletSyncJobQueue(database: database);
        addTearDown(() async {
          await queue.close();
          database.dispose();
        });
        final reader = _Revisions();
        Future<List<WalletSyncJobClaim>> claim() async {
          final jobs = await readWalletSyncJobs([reader.key], reader);
          return switch (jobs) {
            Ok(:final value) => queue.reconcileAndClaim(
              value,
              chain: WalletSyncChain.bitcoin,
            ),
            Err() => <WalletSyncJobClaim>[],
          };
        }

        final failed = (await claim()).single;
        await queue.completeFailure(failed, permanent: true);
        expect(await claim(), isEmpty);
        reader.available = false;
        expect(await claim(), isEmpty);
        reader.available = true;
        expect(await claim(), isEmpty);
        if (changeGeneration) {
          reader.generation++;
        } else {
          reader.revision++;
        }
        expect(await claim(), hasLength(1));
      },
    );
  }

  test(
    'pending revisions abort instead of returning a partial catalog',
    () async {
      final reader = _Revisions()..lifecycle = WalletLifecycle.pendingWrite;
      expect(
        await readWalletSyncJobs([reader.key], reader),
        isA<Err<List<WalletRevision>, TransactionSyncFailure>>(),
      );
      reader.lifecycle = WalletLifecycle.deleted;
      final jobs = await readWalletSyncJobs([reader.key], reader);
      expect(
        (jobs as Ok<List<WalletRevision>, TransactionSyncFailure>).value,
        isEmpty,
      );
    },
  );
}

final class _Revisions implements WalletRevisionReader {
  final key = WalletKey(id: 'wallet', network: BitcoinNetwork.testnet);
  var generation = 1;
  var revision = 1;
  var available = true;
  var lifecycle = WalletLifecycle.active;

  @override
  Future<Result<WalletRevisionState, TransactionSyncFailure>> read(
    WalletKey key,
  ) async => available
      ? Ok(
          WalletRevisionState(
            stamp: WalletRevision(
              key: key,
              generation: generation,
              revision: revision,
            ),
            lifecycle: lifecycle,
          ),
        )
      : const Err(TransactionSyncStorageFailure());

  @override
  Stream<WalletRevisionState> watch(WalletKey key) => const Stream.empty();
}
