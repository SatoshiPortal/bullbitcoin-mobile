import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:ark/src/data/ark_writer_lock.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ark/src/data/ark_codec.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('ark-store-'));
  tearDown(() => temp.deleteSync(recursive: true));
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'test',
  );
  final source = Uri.parse('http://localhost:3000');
  ArkOperation operation(String id) => ArkOperation(
    id: id,
    kind: ArkOperationKind.claim,
    status: ArkOperationStatus.admitted,
    chainSource: source,
    configGeneration: 1,
  );
  test('existing-only never creates missing metadata or locks', () {
    expect(
      () => ArkStore.open('${temp.path}/missing', create: false),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      ArkWriterLock.acquire('${temp.path}/missing-lock', existingOnly: true),
      isA<Err>(),
    );
    expect(temp.listSync(), isEmpty);
  });
  test(
    'real SQLite lock excludes second connection until explicit release',
    () {
      final first = ArkWriterLock.acquire('${temp.path}/lock');
      expect(first, isA<Ok>());
      expect(
        ArkWriterLock.acquire('${temp.path}/lock'),
        isA<Err<ArkWriterLock, ArkWalletFailure>>(),
      );
      (first as Ok<ArkWriterLock, ArkWalletFailure>).value.release();
      final second = ArkWriterLock.acquire('${temp.path}/lock');
      expect(second, isA<Ok>());
      (second as Ok<ArkWriterLock, ArkWalletFailure>).value.release();
    },
  );
  test('operation evidence survives reopen independently of quote TTL', () {
    final path = '${temp.path}/state';
    final store = ArkStore.open(path, create: true);
    store.saveOperation(
      operation('claim-1'),
      'expired-quote',
      evidence: {'raw': 'signed-public-transaction'},
    );
    store.close();
    final reopened = ArkStore.open(path, create: false);
    expect(
      reopened.operation('claim-1')?.operation.status,
      ArkOperationStatus.admitted,
    );
    expect(
      reopened.operation('claim-1')?.evidence?['raw'],
      'signed-public-transaction',
    );
    expect(reopened.operations.single.chainSource, source);
    reopened.close();
  });
  test(
    'actual claims debit cumulative allowance; skipped ids retain remainder',
    () {
      final store = ArkStore.open('${temp.path}/state', create: true);
      expect(
        store.createClaimAuthority(
          'exit',
          ['a', 'b'],
          'destination',
          Sats.fromInt(100),
        ),
        isTrue,
      );
      expect(
        store.createClaimAuthority(
          'overlap',
          ['b'],
          'destination',
          Sats.fromInt(100),
        ),
        isFalse,
      );
      final authority = store.claimAuthority(
        ['a', 'b'],
        'destination',
        Sats.fromInt(100),
      );
      expect(authority, 'exit');
      store.commitClaim(
        'exit',
        operation('first'),
        'quote',
        {'a'},
        Sats.fromInt(60),
        {'raw': 'raw-a'},
      );
      expect(
        store.claimAuthority(['a'], 'destination', Sats.fromInt(1)),
        isNull,
      );
      expect(
        store.claimAuthority(['b'], 'destination', Sats.fromInt(100)),
        isNull,
      );
      expect(store.claimAuthority(['b'], 'other', Sats.fromInt(40)), isNull);
      expect(
        store.claimAuthority(['b'], 'destination', Sats.fromInt(40)),
        'exit',
      );
      expect(
        () => store.commitClaim(
          'exit',
          operation('bad'),
          'quote',
          {'b'},
          Sats.fromInt(41),
          {'raw': 'raw-b'},
        ),
        throwsFormatException,
      );
      expect(store.operation('bad'), isNull);
      expect(
        store.claimAuthority(['b'], 'destination', Sats.fromInt(40)),
        'exit',
      );
      store.close();
    },
  );
  test(
    'snapshot round trip preserves nullable values and detailed sections',
    () {
      final store = ArkStore.open('${temp.path}/state', create: true);
      store.saveSnapshot(
        ArkSnapshot(
          account: account,
          revision: 2,
          observedAt: DateTime.utc(2026),
          operations: [operation('claim')],
          vtxoCompleteness: ArkSectionCompleteness.complete,
          exitDetails: [
            ArkExit(
              id: 'exit',
              amount: Sats.fromInt(1000),
              status: ArkExitStatus.claimable,
              claimableHeight: 200,
            ),
          ],
          pendingBoards: [
            ArkPendingBoard(
              vtxoId: 'board',
              fundingTxid: 'txid',
              amount: Sats.fromInt(2000),
              expiryHeight: 500,
            ),
          ],
        ),
      );
      final result = store.snapshot;
      expect(result?.spendable, isNull);
      expect(result?.vtxoInventoryComplete, isTrue);
      expect(result?.exitDetails.single.claimableHeight, 200);
      expect(result?.pendingBoards.single.expiryHeight, 500);
      expect(result?.operations.single.id, 'claim');
      store.close();
    },
  );
  test('read-only projection connection cannot mutate existing metadata', () {
    final path = '${temp.path}/readonly';
    final writer = ArkStore.open(path, create: true);
    writer.put('marker', {'value': 'original'});
    writer.close();
    final reader = ArkStore.open(path, create: false, readOnly: true);
    expect(reader.get('marker')?['value'], 'original');
    expect(
      () => reader.put('marker', {'value': 'changed'}),
      throwsA(isA<SqliteException>()),
    );
    reader.close();
    expect(
      () => ArkStore.open('${temp.path}/new', create: true, readOnly: true),
      throwsFormatException,
    );
  });
  test('decoded movement evidence is immutable', () {
    final value = movementFromJson({
      'id': 'm',
      'kind': 'renewal',
      'status': 'successful',
      'amount': null,
      'fee': null,
      'createdAt': null,
      'txid': null,
      'inputs': ['old'],
      'outputs': ['new'],
    });
    expect(() => value.outputVtxoIds.clear(), throwsUnsupportedError);
  });
}
