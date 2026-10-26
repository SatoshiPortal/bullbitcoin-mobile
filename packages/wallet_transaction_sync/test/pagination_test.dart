import 'package:test/test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

import 'support/fakes.dart';

void main() {
  late RecordingSource source;
  late WalletTransactionSyncFacade facade;

  setUp(() async {
    source = RecordingSource()
      ..observationBuilder = (registration) => WalletSourceObservation(
        key: registration.key,
        registration: registration,
        transactions: [
          for (final txid in const ['a', 'b', 'c'])
            WalletTransaction(
              txid: txid,
              amountSats: 1,
              position: const UnknownPosition(),
            ),
        ],
      );
    facade = buildFacade(source, RecordingMetadata());
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );
  });

  test('pages chain through the cursor until exhaustion', () async {
    final first = okValue(
      await facade.listLocal(
        const ListLocalTransactionsRequest(testKey, pageSize: 2),
      ),
    );
    expect(first.items.map((item) => item.transaction.txid), ['a', 'b']);
    expect(first.nextCursor, '2:1');

    final second = okValue(
      await facade.listLocal(
        ListLocalTransactionsRequest(
          testKey,
          pageSize: 2,
          cursor: first.nextCursor,
        ),
      ),
    );
    expect(second.items.map((item) => item.transaction.txid), ['c']);
    expect(second.nextCursor, isNull);
  });

  test('out-of-range offsets return a typed failure, never a throw', () async {
    expect(
      errFailure(
        await facade.listLocal(
          const ListLocalTransactionsRequest(testKey, cursor: '999:1'),
        ),
      ),
      isA<InvalidPaginationFailure>(),
    );
    expect(
      errFailure(
        await facade.listLocal(
          const ListLocalTransactionsRequest(testKey, cursor: '-1:1'),
        ),
      ),
      isA<InvalidPaginationFailure>(),
    );
  });

  test('non-positive page sizes return a typed failure', () async {
    expect(
      errFailure(
        await facade.listLocal(
          const ListLocalTransactionsRequest(testKey, pageSize: -1),
        ),
      ),
      isA<InvalidPaginationFailure>(),
    );
    expect(
      errFailure(
        await facade.listLocal(
          const ListLocalTransactionsRequest(testKey, pageSize: 0),
        ),
      ),
      isA<InvalidPaginationFailure>(),
    );
  });

  test('malformed cursors return a typed failure', () async {
    for (final cursor in const ['malformed', 'x:1', '1:y', '1:2:3', ':']) {
      expect(
        errFailure(
          await facade.listLocal(
            ListLocalTransactionsRequest(testKey, cursor: cursor),
          ),
        ),
        isA<InvalidPaginationFailure>(),
        reason: 'cursor "$cursor" must be rejected as invalid',
      );
    }
  });

  test('a cursor from another revision reports snapshot expiry', () async {
    expect(
      errFailure(
        await facade.listLocal(
          const ListLocalTransactionsRequest(testKey, cursor: '0:99'),
        ),
      ),
      isA<SnapshotExpiredFailure>(),
    );
  });
}
