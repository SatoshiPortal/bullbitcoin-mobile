import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/src/write/lease_diagnostics.dart';
import 'package:transaction_sync/src/write/revision_store.dart';
import 'package:transaction_sync/src/write/sqlite_wallet_revision_reader.dart';
import 'package:transaction_sync/src/write/writer_lock.dart';
import 'package:transaction_sync/src/write/writer_session.dart';
import 'package:transaction_sync/src/write/writer_sync_operation.dart';
import 'package:transaction_sync/transaction_sync.dart';

import 'native_wallet_writer_test.dart'
    show Catalog, Sessions, Sync, descriptor, key;

/// Blocks inside the native step until [finish] completes.
final class _HeldSync implements WriterSyncOperation {
  final started = Completer<void>();
  final finish = Completer<void>();
  @override
  Future<Result<void, TransactionSyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    required int? issuedReceiveIndex,
  }) async {
    started.complete();
    await finish.future;
    return const Ok(null);
  }
}

/// Tries the reader admission from a separate isolate and connection.
Future<bool> _admittedElsewhere(String directory, WalletKey wallet) =>
    Isolate.run(() {
      final lock = WriterLock.acquire(
        directory,
        wallet,
        diagnostics: LeaseDiagnostics(
          role: LeaseRole.reader,
          intent: LeaseIntent.snapshot,
          sink: (_, _) {},
        ),
      );
      if (lock case Ok(:final value)) {
        value.release();
        return true;
      }
      return false;
    });

void main() {
  late Directory dir;
  late RevisionStore store;
  late SqliteWalletRevisionReader reader;
  late Sessions sessions;

  WriterSession worker({PublicWalletDescriptor? given}) => WriterSession.worker(
    documentsDirectory: dir.path,
    revisions: store,
    reader: reader,
    sessions: sessions,
    descriptor: given ?? descriptor,
    diagnostics: (_, _) {},
    leaseScope: LeaseScope.compute,
  );

  WriterSession app() => WriterSession.app(
    documentsDirectory: dir.path,
    revisions: store,
    reader: reader,
    sessions: sessions,
    catalog: Catalog(),
    diagnostics: (_, _) {},
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('writer-session-');
    store = RevisionStore.openForeground('${dir.path}/revisions.sqlite');
    reader = SqliteWalletRevisionReader(store);
    sessions = Sessions()..exists = true;
  });
  tearDown(() async {
    await reader.close();
    store.close();
    dir.deleteSync(recursive: true);
  });

  test('the worker entry adopts an existing native store', () async {
    final adopted = await worker().create(
      key,
      expectedGeneration: 0,
      existingOnly: true,
    );
    expect(adopted, isA<Ok<WriterOutcome, TransactionSyncFailure>>());
    expect(store.record(key)?.state.lifecycle, WalletLifecycle.active);
    expect(store.record(key)?.intent, isNull);
  });

  test('a foreground worker sync resumes every interrupted intent', () async {
    expect(await app().create(key, expectedGeneration: 0), isA<Ok>());
    for (final (intent, candidate) in [
      (WriteIntent.receive, 4),
      (WriteIntent.load, null),
      (WriteIntent.sync, null),
    ]) {
      store.begin(key, intent, candidate: candidate);
      expect(
        await worker().sync(
          key,
          expectedGeneration: 1,
          operation: Sync((_) {}),
        ),
        isA<Ok>(),
        reason: intent.name,
      );
      expect(store.record(key)?.intent, isNull, reason: intent.name);
    }
    expect(sessions.revealed, contains(4));
    expect(store.record(key)?.issued, 4);
  });

  test('a headless worker sync never resumes an interrupted intent', () async {
    expect(await app().create(key, expectedGeneration: 0), isA<Ok>());
    store.begin(key, WriteIntent.receive, candidate: 4);
    final result = await worker().sync(
      key,
      expectedGeneration: 1,
      operation: Sync((_) {}),
      reconcile: false,
    );
    expect(
      (result as Err<WriterOutcome, TransactionSyncFailure>).failure,
      isA<TransactionSyncBusyFailure>(),
    );
    expect(store.record(key)?.intent, WriteIntent.receive);
    expect(sessions.revealed, isEmpty);
  });

  test('a descriptor whose hash differs from the store is refused', () async {
    expect(await app().create(key, expectedGeneration: 0), isA<Ok>());
    final other = LiquidWalletDescriptor(
      key: key,
      scriptType: ScriptType.bip84,
      origin: 'test',
      combinedCtDescriptor: 'ct(slip77(other),wpkh(public))',
    );
    var ran = false;
    final result = await worker(
      given: other,
    ).sync(key, expectedGeneration: 1, operation: Sync((_) => ran = true));
    expect(
      (result as Err<WriterOutcome, TransactionSyncFailure>).failure,
      isA<TransactionSyncInvalidCatalogFailure>(),
    );
    expect(ran, isFalse);
  });

  test('another isolate is excluded until the native step completes', () async {
    expect(await app().create(key, expectedGeneration: 0), isA<Ok>());
    final held = _HeldSync();
    final pass = worker().sync(key, expectedGeneration: 1, operation: held);
    await held.started.future;
    expect(await _admittedElsewhere(dir.path, key), isFalse);
    // The app entry waits its bounded time, then reports busy.
    expect(
      await app().create(key, expectedGeneration: 1),
      isA<Err<WriterOutcome, TransactionSyncFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<TransactionSyncBusyFailure>(),
      ),
    );
    held.finish.complete();
    expect(await pass, isA<Ok>());
    expect(await _admittedElsewhere(dir.path, key), isTrue);
  });
}
