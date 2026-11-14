import 'package:sync/src/data/write/datasources/native_store_errors.dart';
import 'dart:async';
import 'package:sync/src/data/lease_diagnostics.dart';
import 'dart:io';
import 'package:bull_logger/bull_logger.dart';

import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';
import 'package:sync/src/data/write/native_write_session.dart';
import 'package:sync/src/data/datasources/spend_gate_store_datasource.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/src/data/write/native_wallet_writer_repository.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/sqlite_wallet_revision_reader.dart';
import 'package:sync/src/data/write/writer_sync_operation.dart';
import 'package:sync/src/data/writer_diagnostics.dart';
import 'package:sync/src/data/write/writer_session.dart';

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

class _Both implements WalletCatalogPort {
  final PublicWalletDescriptor bitcoin;
  _Both(this.bitcoin);
  @override
  Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey wanted,
  ) async => Ok(wanted == bitcoin.key ? bitcoin : descriptor);
  @override
  Future<Result<List<PublicWalletDescriptor>, TransactionSyncFailure>>
  list() async => Ok([descriptor, bitcoin]);
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

class RepairSync implements WriterSyncOperation {
  @override
  Future<Result<void, TransactionSyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    required int? issuedReceiveIndex,
  }) async => const Err(TransactionSyncNeedsRepairFailure());
}

class UnchangedSync extends Sync implements WriterSyncChanges {
  UnchangedSync() : super((_) {});
  @override
  bool get hasChanges => false;
}

class UnrecognizedNativeDescriptorException implements Exception {
  @override
  String toString() => 'sensitive-sentinel';
}

class _Reporter implements LoggerReporter {
  final errors = <Object>[];
  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) {
    errors.add(exception);
  }

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async {
    throw StateError('Unexpected shout');
  }
}

void main() {
  late Directory dir;
  late RevisionStoreDatasource store;
  late SqliteWalletRevisionReader reader;
  late Sessions sessions;
  late Reserved reserved;
  late NativeWalletWriterRepository writer;
  late WriterSession session;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('writer-test-');
    store = RevisionStoreDatasource.openForeground(
      '${dir.path}/metadata.sqlite',
    );
    reader = SqliteWalletRevisionReader(store);
    SpendGateStoreDatasource.provision(spendGateStorePath(dir.path));
    sessions = Sessions();
    reserved = Reserved();
    writer = NativeWalletWriterRepository.withSessions(
      documentsDirectory: dir.path,
      revisions: store,
      reader: reader,
      catalog: Catalog(),
      reservedAddresses: reserved,
      sessions: sessions,
    );
    session = WriterSession.app(
      documentsDirectory: dir.path,
      revisions: store,
      reader: reader,
      sessions: sessions,
      catalog: Catalog(),
    );
    expect(await writer.create(key, expectedGeneration: 0), isA<Ok>());
  });
  tearDown(() async {
    await reader.close();
    store.close();
    dir.deleteSync(recursive: true);
  });

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
          final reader = admitted.value as ReadLease;
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
    'unknown native cause has one persisted owner without foreign data',
    () async {
      final reporter = _Reporter();
      await initializeLogging(directory: dir, reporter: reporter);
      sessions.beforeOpen = () => throw UnrecognizedNativeDescriptorException();
      for (var i = 0; i < 2; i++) {
        final result = await writer.receive(key, expectedGeneration: 1);
        expect(
          result,
          isA<Err>().having(
            (r) => r.failure,
            'failure',
            isA<TransactionSyncStorageFailure>(),
          ),
        );
      }
      final lines = await log.readLogs();
      expect(lines.where((line) => line.contains('native exception')), isEmpty);
      expect(
        lines.where((line) => line.split('\t')[1] == 'SEVERE'),
        hasLength(1),
      );
      expect(lines.join(), isNot(contains('sensitive-sentinel')));
      expect(lines.join(), contains('category=storage'));
      expect(lines.join(), isNot(contains('category=[REDACTED]')));
      expect(reporter.errors, ['storage']);
      sessions.beforeOpen = null;
      expect(await writer.receive(key, expectedGeneration: 1), isA<Ok>());
      sessions.beforeOpen = () => throw UnrecognizedNativeDescriptorException();
      expect(await writer.receive(key, expectedGeneration: 1), isA<Err>());
      expect(
        (await log.readLogs()).where((line) => line.split('\t')[1] == 'SEVERE'),
        hasLength(2),
      );
      expect(reporter.errors, hasLength(2));
      await log.flush();
    },
  );

  test('connection failure category survives persisted redaction', () async {
    await initializeLogging(directory: dir);
    expect(
      await session.sync(
        key,
        expectedGeneration: 1,
        operation: FailedSync(true),
      ),
      isA<Err>(),
    );
    final lines = await log.readLogs();
    expect(lines.join(), contains('category=connection'));
    expect(lines.join(), isNot(contains('category=[REDACTED]')));
    await log.flush();
  });

  test('worker writer leaves terminal failure to the engine', () async {
    await initializeLogging(directory: dir);
    final worker = WriterSession.worker(
      documentsDirectory: dir.path,
      revisions: store,
      reader: reader,
      sessions: sessions,
      descriptor: descriptor,
      diagnostics: persistWriterDiagnostic,
      leaseScope: LeaseScope.compute,
    );
    expect(
      await worker.sync(
        key,
        expectedGeneration: 1,
        operation: FailedSync(true),
      ),
      isA<Err>(),
    );
    final lines = await log.readLogs();
    expect(
      lines.where(
        (line) => ['WARNING', 'SEVERE'].contains(line.split('\t')[1]),
      ),
      isEmpty,
    );
    expect(
      lines.where((line) => line.contains('Writer revision invalidated')),
      hasLength(1),
    );
    expect(lines.join(), contains('reason=connection'));
  });

  test(
    'failed sync releases the writer; hydration can briefly contend',
    () async {
      expect(
        await session.sync(
          key,
          expectedGeneration: 1,
          operation: FailedSync(false),
        ),
        isA<Err>(),
      );
      final admission = await writer.acquire(key);
      expect(admission, isA<Ok>());
      final lease = (admission as Ok<ReadLease, TransactionSyncFailure>).value;
      try {
        expect(
          await session.sync(
            key,
            expectedGeneration: 1,
            operation: Sync((_) {}),
          ),
          isA<Err<WriterOutcome, TransactionSyncFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<TransactionSyncBusyFailure>(),
          ),
        );
      } finally {
        await lease.release();
      }
      expect(
        await session.sync(key, expectedGeneration: 1, operation: Sync((_) {})),
        isA<Ok>(),
      );
    },
  );

  test('headless retries syncFailed without reconciliation', () async {
    expect(
      await session.sync(
        key,
        expectedGeneration: 1,
        operation: FailedSync(true),
      ),
      isA<Err>(),
    );
    expect(store.record(key)?.state.syncFailed, isTrue);
    final before = store.record(key)?.state.stamp.revision;
    final opens = sessions.opens;
    var ran = false;
    expect(
      await session.sync(
        key,
        expectedGeneration: 1,
        reconcile: false,
        operation: Sync((_) => ran = true),
      ),
      isA<Ok>(),
    );
    expect(ran, isTrue);
    expect(sessions.opens, opens);
    expect(store.record(key)?.state.syncFailed, isFalse);
    expect(store.record(key)?.state.stamp.revision, (before ?? -1) + 1);
  });

  test(
    'repeated adoption preserves the revision of an unchanged store',
    () async {
      await initializeLogging(directory: dir);
      final before = store.record(key)?.state.stamp;
      for (var i = 0; i < 5; i++) {
        final result = await writer.create(
          key,
          expectedGeneration: 1,
          existingOnly: true,
        );
        expect(result, isA<Ok<WriterOutcome, TransactionSyncFailure>>());
        expect((result as Ok).value, isA<WriterUnchanged>());
        expect(store.record(key)?.state.stamp, before);
        expect(store.record(key)?.intent, isNull);
      }
      final lines = await log.readLogs();
      expect(
        lines.where((line) => line.contains('outcome=unchanged')),
        hasLength(5),
      );
      expect(lines.join(), isNot(contains('operation committed')));
    },
  );

  test(
    'repair failure carries the stamp observed while holding the lease',
    () async {
      final before = store.record(key)?.state.stamp;
      final result = await session.sync(
        key,
        expectedGeneration: 1,
        operation: RepairSync(),
      );
      expect(
        result,
        isA<Err<WriterOutcome, TransactionSyncFailure>>().having(
          (result) =>
              (result.failure as TransactionSyncNeedsRepairFailure).revision,
          'writer stamp',
          before,
        ),
      );
    },
  );

  test('headless admission never reconciles pending work', () async {
    store.begin(key, WriteIntent.sync);
    final before = store.record(key);
    final opens = sessions.opens;
    final result = await session.sync(
      key,
      expectedGeneration: 1,
      reconcile: false,
      operation: Sync((_) => fail('must not sync')),
    );
    expect(result, isA<Err<WriterOutcome, TransactionSyncFailure>>());
    expect(sessions.opens, opens);
    expect(store.record(key)?.intent, before?.intent);
    expect(store.record(key)?.state.stamp, before?.state.stamp);
  });

  test('initial scan rejection precedes durable intent', () async {
    final before = store.record(key)?.state.stamp;
    final result = await session.sync(
      key,
      expectedGeneration: 1,
      reconcile: false,
      preflight: () async =>
          const Err(TransactionSyncInitialScanRequiredFailure()),
      operation: Sync((_) => fail('must not sync')),
    );
    expect(result, isA<Err<WriterOutcome, TransactionSyncFailure>>());
    expect(store.record(key)?.intent, isNull);
    expect(store.record(key)?.state.stamp, before);
  });

  test(
    'explicit advance skips reserved indices and persists the new address',
    () async {
      final first = await writer.receive(key, expectedGeneration: 1) as Ok;
      expect((first.value as ReceiveAddressIssued).index, 0);
      reserved.indices.add(1);
      final next =
          await writer.receive(key, expectedGeneration: 1, advance: true) as Ok;
      expect((next.value as ReceiveAddressIssued).index, 2);
      final same = await writer.receive(key, expectedGeneration: 1) as Ok;
      expect((same.value as ReceiveAddressIssued).index, 2);
    },
  );

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

  test(
    'missing active store rebuilds and restores issued receive index',
    () async {
      reserved.indices.addAll([0, 1]);
      expect(await writer.receive(key, expectedGeneration: 1), isA<Ok>());
      sessions.exists = false;
      sessions.revealed.clear();
      expect(
        await writer.create(key, expectedGeneration: 1, existingOnly: true),
        isA<Ok>(),
      );
      expect(sessions.revealed, [2]);
      expect(store.record(key)?.issued, 2);
      expect(store.record(key)?.needsSync, isTrue);
      expect(store.record(key)?.intent, isNull);
    },
  );

  test('missing adoption leaves no load intent or revision', () async {
    final empty = RevisionStoreDatasource.openForeground(
      '${dir.path}/empty.sqlite',
    );
    final adopter = NativeWalletWriterRepository.withSessions(
      documentsDirectory: dir.path,
      revisions: empty,
      reader: SqliteWalletRevisionReader(empty),
      catalog: Catalog(),
      reservedAddresses: reserved,
      sessions: Sessions(),
    );
    try {
      expect(
        await adopter.create(key, expectedGeneration: 0, existingOnly: true),
        isA<Err>(),
      );
      expect(empty.record(key), isNull);
    } finally {
      empty.close();
    }
  });

  test(
    'unchanged successful sync preserves revision but publishes recovery',
    () async {
      final before = store.record(key)?.state.stamp;
      final unchanged = await session.sync(
        key,
        expectedGeneration: 1,
        operation: UnchangedSync(),
      );
      expect(unchanged, isA<Ok<WriterOutcome, TransactionSyncFailure>>());
      expect(
        (unchanged as Ok<WriterOutcome, TransactionSyncFailure>).value,
        isA<WriterUnchanged>(),
      );
      expect(store.record(key)?.state.stamp, before);
      expect(store.record(key)?.state.syncFailed, isFalse);
      expect(store.record(key)?.intent, isNull);
      expect(
        await session.sync(
          key,
          expectedGeneration: 1,
          operation: FailedSync(false),
        ),
        isA<Err>(),
      );
      expect(store.record(key)?.state.syncFailed, isTrue);
      final recovered = await session.sync(
        key,
        expectedGeneration: 1,
        operation: UnchangedSync(),
      );
      expect(
        (recovered as Ok<WriterOutcome, TransactionSyncFailure>).value,
        isA<WriterCommitted>(),
      );
      expect(store.record(key)?.state.syncFailed, isFalse);
      expect(
        store.record(key)?.state.stamp.revision,
        (before?.revision ?? 0) + 1,
      );
    },
  );

  for (final mutated in [false, true]) {
    test('failed sync clears intent with mutation=$mutated', () async {
      final before = store.record(key)?.state.stamp.revision;
      expect(
        await session.sync(
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
    'interrupted missing-store rebuild restores indices before admission',
    () async {
      reserved.indices.addAll([0, 1]);
      expect(await writer.receive(key, expectedGeneration: 1), isA<Ok>());
      sessions.exists = false;
      sessions.revealed.clear();
      sessions.beforePersist = () =>
          throw const FileSystemException('interrupted');
      expect(
        await writer.create(key, expectedGeneration: 1, existingOnly: true),
        isA<Err>(),
      );
      expect(sessions.exists, isTrue);
      sessions.beforePersist = null;
      expect(
        await writer.create(key, expectedGeneration: 1, existingOnly: true),
        isA<Ok>(),
      );
      expect(sessions.revealed, [2]);
      expect(store.record(key)?.needsSync, isTrue);
      expect(await writer.acquire(key), isA<Err>());
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
      await (lease.value as ReadLease).release();
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
      await reader.close();
      store.close();
      store = RevisionStoreDatasource.openForeground(
        '${dir.path}/metadata.sqlite',
      );
      reader = SqliteWalletRevisionReader(store);
      writer = NativeWalletWriterRepository.withSessions(
        documentsDirectory: dir.path,
        revisions: store,
        reader: reader,
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
      await (admission.value as ReadLease).release();
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
      final result = await session.sync(
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

  test('a damaged spend gate fails closed for Bitcoin only', () async {
    final bitcoin = BitcoinWalletDescriptor(
      key: WalletKey(id: 'bitcoin', network: BitcoinNetwork.testnet),
      scriptType: ScriptType.bip84,
      origin: 'test',
      externalDescriptor: 'wpkh(public/0)',
      internalDescriptor: 'wpkh(public/1)',
    );
    final catalog = _Both(bitcoin);
    NativeWalletWriterRepository writing(RevisionStoreDatasource revisions) =>
        NativeWalletWriterRepository.withSessions(
          documentsDirectory: dir.path,
          revisions: revisions,
          reader: SqliteWalletRevisionReader(revisions),
          catalog: catalog,
          reservedAddresses: reserved,
          sessions: sessions,
        );
    WriterSession syncing(RevisionStoreDatasource revisions) =>
        WriterSession.app(
          documentsDirectory: dir.path,
          revisions: revisions,
          reader: SqliteWalletRevisionReader(revisions),
          sessions: sessions,
          catalog: catalog,
        );
    BitcoinSpendGate gate(RevisionStoreDatasource revisions) =>
        BitcoinSpendGate(
          revisions: revisions,
          documentsDirectory: dir.path,
          catalog: catalog,
        );
    expect(
      await writing(store).create(bitcoin.key, expectedGeneration: 0),
      isA<Ok>(),
    );
    expect(await gate(store).check(bitcoin.key), BitcoinSpendStatus.ready);
    File(
      spendGateStorePath(dir.path),
    ).writeAsStringSync('damaged' * 1000, flush: true);

    // Every sync pass reopens the metadata, for Liquid wallets too.
    final reopened = RevisionStoreDatasource.openExisting(
      '${dir.path}/metadata.sqlite',
    );
    addTearDown(reopened.close);
    expect(
      await syncing(
        reopened,
      ).sync(key, expectedGeneration: 1, operation: Sync((_) {})),
      isA<Ok>(),
    );
    expect(
      await gate(reopened).check(bitcoin.key),
      BitcoinSpendStatus.unavailable,
    );
    expect(
      await syncing(
        reopened,
      ).sync(bitcoin.key, expectedGeneration: 1, operation: Sync((_) {})),
      isA<Err<WriterOutcome, TransactionSyncFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<TransactionSyncStorageFailure>(),
      ),
    );
  });

  test('read publishes externally committed revision once', () async {
    expect(await reader.read(key), isA<Ok>());
    final observed = <WalletRevisionState>[];
    final subscription = reader.watch(key).listen(observed.add);
    final other = RevisionStoreDatasource.openExisting(
      '${dir.path}/metadata.sqlite',
    );
    try {
      other.begin(key, WriteIntent.sync);
      other.finish(key);
      expect(await reader.read(key), isA<Ok>());
      expect(await reader.read(key), isA<Ok>());
      await Future<void>.delayed(Duration.zero);
      expect(observed, hasLength(1));
      expect(observed.single.stamp, other.record(key)?.state.stamp);
    } finally {
      await subscription.cancel();
      other.close();
    }
  });

  test(
    'subscribe before write observes committed revision with cleared intent',
    () async {
      final changed = reader.watch(key).first;
      expect(await writer.receive(key, expectedGeneration: 1), isA<Ok>());
      final event = await changed;
      expect(event.stamp, store.record(key)?.state.stamp);
      expect(event.lifecycle, WalletLifecycle.active);
      expect(store.record(key)?.intent, isNull);
    },
  );
}
