import 'dart:async';
import 'package:bull_logger/bull_logger.dart';
import 'package:transaction_sync/src/write/lease_diagnostics.dart';
import 'dart:io';

import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/write.dart';
import 'package:transaction_sync/src/write/native_write_session.dart';
import 'package:transaction_sync/src/write/revision_store.dart';

final key = WalletKey(id: 'test', network: LiquidNetwork.testnet);
final descriptor = LiquidWalletDescriptor(
  key: key,
  scriptType: ScriptType.bip84,
  origin: 'test',
  combinedCtDescriptor: 'ct(slip77(public),wpkh(public))',
);

class Catalog implements WalletCatalogPort {
  @override
  Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey key,
  ) async => Ok(descriptor);
  @override
  Future<Result<List<PublicWalletDescriptor>, TransactionSyncFailure>>
  list() async => Ok([descriptor]);
}

class Reserved implements ReservedAddressPort {
  final indices = <int>{};
  bool fail = false;
  @override
  Future<Result<bool, TransactionSyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => fail
      ? const Err(TransactionSyncStorageFailure())
      : Ok(indices.contains(int.parse(address)));
}

class Sessions implements NativeWriteSessions {
  final used = <int>{};
  final revealed = <int>[];
  bool exists = false;
  bool conflict = false;
  bool failDelete = false;
  int opens = 0;
  void Function()? beforeOpen;
  void Function()? beforePersist;
  void Function()? beforeDelete;
  @override
  Future<NativeWriteSession> open(
    PublicWalletDescriptor descriptor, {
    required bool create,
  }) async {
    beforeOpen?.call();
    if (conflict) throw const lwk.LwkError(msg: 'UpdateOnDifferentStatus');
    if (!exists && !create) throw const NativeStoreMissing();
    exists = true;
    opens++;
    return Session(this);
  }

  @override
  Future<void> delete(WalletKey key) async {
    beforeDelete?.call();
    if (failDelete) throw const FileSystemException('injected');
    exists = false;
    conflict = false;
    used.clear();
  }
}

class Session implements NativeWriteSession {
  final Sessions owner;
  Session(this.owner);
  @override
  Future<int> firstUnusedIndex() async => 0;
  @override
  Future<String> address(int index) async => '$index';
  @override
  Future<bool> isUsed(int index, String address) async =>
      owner.used.contains(index);
  @override
  Future<void> revealAndPersist(int index) async {
    owner.beforePersist?.call();
    owner.revealed.add(index);
  }

  @override
  void close() {}
}

class Sync implements WriterSyncOperation {
  final void Function(int?) action;
  Sync(this.action);
  @override
  Future<Result<void, TransactionSyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    required int? issuedReceiveIndex,
  }) async {
    action(issuedReceiveIndex);
    return const Ok(null);
  }
}

class FailedSync implements WriterSyncOperation, WriterSyncMutation {
  @override
  final bool mayHaveMutated;
  FailedSync(this.mayHaveMutated);
  @override
  Future<Result<void, TransactionSyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    required int? issuedReceiveIndex,
  }) async => const Err(TransactionSyncConnectionFailure());
}

void main() {
  late Directory dir;
  late RevisionStore store;
  late Sessions sessions;
  late Reserved reserved;
  late NativeWalletWriter writer;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('writer-test-');
    store = RevisionStore('${dir.path}/metadata.sqlite');
    sessions = Sessions();
    reserved = Reserved();
    writer = NativeWalletWriter.withSessions(
      lockDirectory: '${dir.path}/locks',
      revisions: store,
      catalog: Catalog(),
      reservedAddresses: reserved,
      sessions: sessions,
    );
    expect(await writer.create(key, expectedGeneration: 0), isA<Ok>());
  });
  tearDown(() async {
    await store.close();
    dir.deleteSync(recursive: true);
  });

  for (final mutated in [false, true]) {
    test('failed sync clears intent with mutation=$mutated', () async {
      final before = store.record(key)?.state.stamp.revision;
      expect(
        await writer.sync(
          key,
          expectedGeneration: 1,
          operation: FailedSync(mutated),
        ),
        isA<Err>(),
      );
      final after = store.record(key);
      expect(after?.intent, isNull);
      expect(after?.state.syncFailed, isTrue);
      expect(after?.state.lifecycle, WalletLifecycle.active);
      expect(after?.state.stamp.revision, mutated ? (before ?? 0) + 1 : before);
      final lease = await writer.acquire(key);
      expect(lease, isA<Ok>());
      if (lease case Ok(:final value)) await value.release();
    });
  }

  test(
    'wait diagnostics persist from 100 ms with safe caller context',
    () async {
      log = Logger.replace(directory: dir);
      final trace = LeaseDiagnostics(
        role: LeaseRole.writer,
        intent: LeaseIntent.receive,
        scope: LeaseScope.compute,
        source: LeaseSource.addressList,
      );
      trace.acquire(waitedMs: 99);
      await log.flush();
      expect(
        await log.readLogs(),
        isNot(contains(contains('event=lease_wait'))),
      );
      trace.acquire(waitedMs: 100);
      await log.flush();
      final lines = (await log.readLogs())
          .where((line) => line.contains('event=lease_wait'))
          .toList();
      expect(lines, hasLength(1));
      expect(lines.single, contains('FINE'));
      expect(
        lines.single,
        contains(
          'role=writer intent=receive scope=compute source=address_list',
        ),
      );
      expect(lines.single, contains('held_ms=0 waited_ms=100'));
    },
  );

  for (final holdMs in [100, 800, 1200]) {
    for (final intent in ['receive', 'create']) {
      test(
        '$intent waits asynchronously for a reader holding $holdMs ms',
        () async {
          log = Logger.replace(directory: dir);
          final admitted = await writer.acquire(key) as Ok;
          final reader = admitted.value as LiquidReadLease;
          final released = Future<void>.delayed(
            Duration(milliseconds: holdMs),
            reader.release,
          );
          var ticks = 0;
          final heartbeat = Timer.periodic(const Duration(milliseconds: 10), (
            _,
          ) {
            ticks++;
          });
          final watch = Stopwatch()..start();
          try {
            final result = intent == 'receive'
                ? await writer.receive(key, expectedGeneration: 1)
                : await writer.create(key, expectedGeneration: 1);
            final elapsedMs = watch.elapsedMilliseconds;
            if (holdMs < 1000) {
              expect(result, isA<Ok>());
              expect(elapsedMs, greaterThanOrEqualTo(holdMs));
            } else {
              expect(
                result,
                isA<Err>().having(
                  (r) => r.failure,
                  'failure',
                  isA<TransactionSyncBusyFailure>(),
                ),
              );
              expect(elapsedMs, inInclusiveRange(1000, 1199));
            }
            expect(ticks, greaterThanOrEqualTo(3));
            await log.flush();
            final lines = await log.readLogs();
            final event = holdMs < 1000 ? 'lease_wait' : 'lease_busy';
            final waits = lines
                .where((line) => line.contains('event=$event role=writer'))
                .toList();
            expect(waits, hasLength(1));
            expect(waits.single, contains('FINE'));
            expect(
              waits.single,
              contains('intent=$intent scope=foreground source=other'),
            );
            final waitedMs = int.parse(
              RegExp(r'waited_ms=(\d+)').firstMatch(waits.single)?.group(1) ??
                  '-1',
            );
            expect(
              waitedMs,
              inInclusiveRange(holdMs < 1000 ? holdMs : 1000, elapsedMs),
            );
            expect(
              lines.where(
                (line) => line.contains('event=lease_busy role=writer'),
              ),
              hasLength(holdMs < 1000 ? 0 : 1),
            );
          } finally {
            heartbeat.cancel();
            await released;
            await log.flush();
          }
          // A timed-out contender must not leave a control transaction behind.
          expect(await writer.receive(key, expectedGeneration: 1), isA<Ok>());
        },
      );
    }
  }

  test(
    'intent precedes persist; reserved and used addresses skipped; reopen reuses',
    () async {
      reserved.indices.add(0);
      sessions.used.add(1);
      sessions.beforeOpen = () =>
          expect(store.record(key)?.intent, WriteIntent.receive);
      sessions.beforePersist = () {
        final pending = store.record(key);
        expect(pending?.intent, WriteIntent.receive);
        expect(pending?.candidate, 2);
        expect(pending?.issued, isNull);
      };
      final first = await writer.receive(key, expectedGeneration: 1) as Ok;
      expect((first.value as ReceiveAddressIssued).index, 2);
      sessions.beforePersist = null;
      final second = await writer.receive(key, expectedGeneration: 1) as Ok;
      expect((second.value as ReceiveAddressIssued).address, '2');
      expect(sessions.opens, 3);
      expect(store.record(key)?.intent, isNull);
    },
  );

  test('finalization failure retains intent and revision atomically', () async {
    final database = sqlite3.open('${dir.path}/metadata.sqlite');
    database.execute(
      "CREATE TRIGGER fail_commit BEFORE UPDATE ON revisions "
      "WHEN NEW.intent IS NULL BEGIN SELECT RAISE(ABORT, 'injected'); END",
    );
    final before = store.record(key)?.state.stamp;
    try {
      expect(await writer.receive(key, expectedGeneration: 1), isA<Err>());
      expect(store.record(key)?.intent, WriteIntent.receive);
      expect(store.record(key)?.state.stamp, before);
      expect(store.record(key)?.issued, isNull);
      database.execute('DROP TRIGGER fail_commit');
      expect(await writer.acquire(key), isA<Err>());
      expect(store.record(key)?.intent, WriteIntent.receive);
      expect(await writer.create(key, expectedGeneration: 1), isA<Ok>());
      final lease = await writer.acquire(key) as Ok;
      await (lease.value as LiquidReadLease).release();
      expect(store.record(key)?.intent, isNull);
      expect(store.record(key)?.issued, 0);
    } finally {
      database.dispose();
    }
  });

  test('reservation lookup failure never becomes unreserved', () async {
    reserved.fail = true;
    expect(await writer.receive(key, expectedGeneration: 1), isA<Err>());
    expect(sessions.revealed, isEmpty);
    expect(store.record(key)?.issued, isNull);
  });

  test(
    'writer reconciles before reader admission after reopening metadata',
    () async {
      store.begin(key, WriteIntent.receive, candidate: 7);
      await store.close();
      store = RevisionStore('${dir.path}/metadata.sqlite');
      writer = NativeWalletWriter.withSessions(
        lockDirectory: '${dir.path}/locks',
        revisions: store,
        catalog: Catalog(),
        reservedAddresses: reserved,
        sessions: sessions,
      );
      expect(await writer.acquire(key), isA<Err>());
      expect(sessions.revealed, isEmpty);
      expect(await writer.create(key, expectedGeneration: 1), isA<Ok>());
      final admission = await writer.acquire(key) as Ok;
      expect(store.record(key)?.issued, 7);
      expect(store.record(key)?.intent, isNull);
      expect(sessions.revealed, [7]);
      expect(await writer.receive(key, expectedGeneration: 1), isA<Err>());
      await (admission.value as LiquidReadLease).release();
      expect(await writer.receive(key, expectedGeneration: 1), isA<Ok>());
    },
  );

  test(
    'tombstone precedes unlink; retry finishes deletion before reimport',
    () async {
      sessions.beforeDelete = () {
        expect(store.record(key)?.state.lifecycle, WalletLifecycle.deleted);
        expect(store.record(key)?.state.stamp.generation, 2);
        expect(store.record(key)?.intent, WriteIntent.delete);
      };
      sessions.failDelete = true;
      expect(await writer.delete(key, expectedGeneration: 1), isA<Err>());
      sessions.failDelete = false;
      expect(await writer.create(key, expectedGeneration: 2), isA<Ok>());
      expect(store.record(key)?.state.stamp.generation, 3);
      expect(await writer.delete(key, expectedGeneration: 1), isA<Err>());
      expect(sessions.exists, isTrue);
    },
  );

  test('delete supersedes an unrecoverable repair intent', () async {
    store.begin(key, WriteIntent.repair);
    sessions.conflict = true;
    expect(await writer.delete(key, expectedGeneration: 1), isA<Ok>());
    expect(store.record(key)?.state.lifecycle, WalletLifecycle.deleted);
    expect(store.record(key)?.state.stamp.generation, 2);
    expect(sessions.exists, isFalse);
  });

  test(
    'repair preserves issued index and blocks receive until successful sync',
    () async {
      reserved.indices.addAll({0, 1, 2});
      expect(await writer.receive(key, expectedGeneration: 1), isA<Ok>());
      sessions.conflict = true;
      expect(await writer.repair(key, expectedGeneration: 1), isA<Ok>());
      expect(store.record(key)?.issued, 3);
      expect(store.record(key)?.needsSync, isTrue);
      expect(await writer.receive(key, expectedGeneration: 1), isA<Err>());
      final result = await writer.sync(
        key,
        expectedGeneration: 1,
        operation: Sync((issued) {
          expect(issued, 3);
          expect(store.record(key)?.intent, WriteIntent.sync);
          sessions.used.add(3);
        }),
      );
      expect(result, isA<Ok>());
      final received = await writer.receive(key, expectedGeneration: 1) as Ok;
      expect((received.value as ReceiveAddressIssued).index, 4);
    },
  );

  test(
    'pending sync only advances conservative revision; keeps repair barrier',
    () async {
      store.begin(key, WriteIntent.repair);
      store.finish(key, needsSync: true);
      store.begin(key, WriteIntent.sync);
      final before = store.record(key)?.state.stamp.revision ?? 0;
      expect(await writer.acquire(key), isA<Err>());
      expect(store.record(key)?.intent, WriteIntent.sync);
      expect(await writer.receive(key, expectedGeneration: 1), isA<Err>());
      expect(store.record(key)?.intent, isNull);
      expect(store.record(key)?.needsSync, isTrue);
      expect(store.record(key)?.state.stamp.revision, before + 1);
    },
  );

  test('read publishes externally committed revision once', () async {
    expect(await store.read(key), isA<Ok>());
    final observed = <WalletRevisionState>[];
    final subscription = store.watch(key).listen(observed.add);
    final other = RevisionStore('${dir.path}/metadata.sqlite');
    try {
      other.begin(key, WriteIntent.sync);
      other.finish(key);
      expect(await store.read(key), isA<Ok>());
      expect(await store.read(key), isA<Ok>());
      await Future<void>.delayed(Duration.zero);
      expect(observed, hasLength(1));
      expect(observed.single.stamp, other.record(key)?.state.stamp);
    } finally {
      await subscription.cancel();
      await other.close();
    }
  });

  test(
    'subscribe before write observes committed revision with cleared intent',
    () async {
      final changed = store.watch(key).first;
      expect(await writer.receive(key, expectedGeneration: 1), isA<Ok>());
      final event = await changed;
      expect(event.stamp, store.record(key)?.state.stamp);
      expect(event.lifecycle, WalletLifecycle.active);
      expect(store.record(key)?.intent, isNull);
    },
  );
}
