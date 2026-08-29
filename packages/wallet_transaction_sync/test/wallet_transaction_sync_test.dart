import 'dart:async';
import 'package:test/test.dart';
import 'package:primitives/primitives.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

class FakeSession implements WalletSourceSession {
  bool closed = false;
  @override
  bool get isClosed => closed;
  @override
  void ensureOpen() {
    if (closed) throw StateError('closed');
  }

  @override
  Future<void> close() async => closed = true;
}

class FakeSource implements WalletTransactionSourcePort {
  WalletSourceObservation? next;
  WalletTransactionSyncFailure? failure;
  int syncCalls = 0;
  final Completer<void>? pause;
  FakeSource({this.pause});
  WalletSourceObservation value(WalletSourceRegistration r) =>
      next ??
      WalletSourceObservation(
        key: r.key,
        registration: r,
        transactions: [
          WalletTransaction(
            txid: 'a',
            amountSats: 10,
            position: const UnknownPosition(),
          ),
        ],
      );
  @override
  Future<Result<WalletSourceObservation, WalletTransactionSyncFailure>>
  refreshLocal(WalletSourceRegistration r, WalletSourceSession session) async =>
      failure == null ? Ok(value(r)) : Err(failure!);
  @override
  Future<Result<WalletSourceObservation, WalletTransactionSyncFailure>>
  synchronize(
    WalletSourceRegistration r,
    WalletSourceSession session, {
    required bool discover,
  }) async {
    syncCalls++;
    if (pause != null) await pause!.future;
    return failure == null ? Ok(value(r)) : Err(failure!);
  }

  @override
  Future<Result<void, WalletTransactionSyncFailure>> delete(
    WalletNetworkKey key,
    WalletSourceSession session,
  ) async => const Ok(null);
}

class FakeMetadata implements WalletSyncMetadataPort {
  final Map<WalletNetworkKey, WalletSyncMetadata> values = {};
  bool failSuccess = false;
  @override
  Future<WalletSyncMetadata?> read(WalletNetworkKey key) async => values[key];
  @override
  Future<void> writeAttempt(WalletNetworkKey key, DateTime at) async {}
  @override
  Future<void> writeSuccess(
    WalletNetworkKey key,
    DateTime at,
    String fingerprint,
  ) async {
    if (failSuccess) throw StateError('offline');
    final old = values[key];
    if (old != null) {
      values[key] = WalletSyncMetadata(
        registration: old.registration,
        lastSuccessfulSyncAt: at,
        contentFingerprint: fingerprint,
      );
    }
  }

  @override
  Future<WalletSyncReceipt?> readReceipt(WalletNetworkKey key) async => null;
  @override
  Future<void> writeReceipt(WalletSyncReceipt receipt) async {}
  @override
  Future<void> writeDeletionMarker(
    WalletNetworkKey key,
    WalletDeletionPhase phase,
  ) async {}
  @override
  Future<void> clear(WalletNetworkKey key) async => values.remove(key);
}

void main() {
  final key = const WalletNetworkKey('w', 'bitcoin', 'testnet');
  final registration = WalletSourceRegistration(
    key: key,
    sourceKind: 'fake',
    configurationFingerprint: 'one',
  );
  WalletTransactionSyncFacade build(FakeSource source, FakeMetadata metadata) =>
      WalletTransactionSyncFacade(
        source: source,
        metadata: metadata,
        coordinator: InMemoryWalletSourceOperationCoordinator(),
      );

  test(
    'local initialization is network-free and reads require initialization',
    () async {
      final source = FakeSource();
      final facade = build(source, FakeMetadata());
      expect(
        await facade.lookupLocal(LookupLocalTransactionRequest(key, 'a')),
        isA<Err>(),
      );
      expect(
        await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
        isA<Ok>(),
      );
      expect(source.syncCalls, 0);
      expect(
        await facade.lookupLocal(LookupLocalTransactionRequest(key, 'a')),
        isA<Ok>(),
      );
    },
  );

  test('watcher replays ready and failed sync preserves revision', () async {
    final source = FakeSource();
    final facade = build(source, FakeMetadata());
    expect(
      await facade.refreshLocalSnapshot(
        RefreshLocalSnapshotRequest(registration),
      ),
      isA<Ok>(),
    );
    final states = <WalletTransactionSyncState>[];
    final sub = facade.watchWalletState(key).listen(states.add);
    await Future<void>.delayed(Duration.zero);
    expect(states.first, isA<WalletStateReady>());
    source.failure = const SourceFailure(SourceFailureReason.unavailable);
    final result = await facade.synchronizeWallet(
      SynchronizeWalletRequest(registration),
    );
    await Future<void>.delayed(Duration.zero);
    expect(result, isA<Err>());
    expect(states.last, isA<WalletStateFailed>());
    expect((states.last as WalletStateFailed).previousRevision, 1);
    await sub.cancel();
  });

  test(
    'new content gets one revision and metadata failure is a warning',
    () async {
      final source = FakeSource();
      final metadata = FakeMetadata();
      final facade = build(source, metadata);
      expect(
        await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
        isA<Ok>(),
      );
      metadata.failSuccess = true;
      final result = await facade.synchronizeWallet(
        SynchronizeWalletRequest(registration),
      );
      final outcome =
          (result
                  as Ok<
                    WalletTransactionSyncOutcome,
                    WalletTransactionSyncFailure
                  >)
              .value;
      expect(outcome.snapshot.revision, 1);
      expect(outcome.warning, isNotNull);
    },
  );

  test('coordinator waits per key but lets independent keys proceed', () async {
    final c = InMemoryWalletSourceOperationCoordinator();
    final release = Completer<void>();
    final entered = Completer<void>();
    final first = c.runExclusive(const WalletSourceKey('a', 'c', 'n'), (
      s,
    ) async {
      entered.complete();
      await release.future;
      return 1;
    });
    await entered.future;
    var secondDone = false;
    final second = c.runExclusive(const WalletSourceKey('a', 'c', 'n'), (
      s,
    ) async {
      secondDone = true;
      return 2;
    });
    await c.runExclusive(const WalletSourceKey('b', 'c', 'n'), (s) async => 3);
    expect(secondDone, isFalse);
    release.complete();
    expect(await first, 1);
    expect(await second, 2);
    expect(secondDone, isTrue);
  });

  test('pagination cursors expire after a revision change', () async {
    final source = FakeSource();
    source.next = WalletSourceObservation(
      key: key,
      registration: registration,
      transactions: [
        WalletTransaction(
          txid: 'a',
          amountSats: 10,
          position: const UnknownPosition(),
        ),
        WalletTransaction(
          txid: 'b',
          amountSats: 11,
          position: const UnknownPosition(),
        ),
      ],
    );
    final facade = build(source, FakeMetadata());
    expect(
      await facade.refreshLocalSnapshot(
        RefreshLocalSnapshotRequest(registration),
      ),
      isA<Ok>(),
    );
    final page =
        (await facade.listLocal(ListLocalTransactionsRequest(key, pageSize: 1))
                as Ok<WalletTransactionPage, WalletTransactionSyncFailure>)
            .value;
    source.next = WalletSourceObservation(
      key: key,
      registration: registration,
      transactions: [
        WalletTransaction(
          txid: 'b',
          amountSats: 11,
          position: const UnknownPosition(),
        ),
      ],
    );
    expect(
      await facade.synchronizeWallet(SynchronizeWalletRequest(registration)),
      isA<Ok>(),
    );
    expect(page.nextCursor, isNotNull);
    expect(
      await facade.listLocal(
        ListLocalTransactionsRequest(key, cursor: page.nextCursor),
      ),
      isA<Err>(),
    );
  });

  test(
    'identical observations keep revision while position changes expire cursors',
    () async {
      final source = FakeSource();
      final metadata = FakeMetadata();
      final facade = build(source, metadata);
      expect(
        await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
        isA<Ok>(),
      );
      final first = await facade.synchronizeWallet(
        SynchronizeWalletRequest(registration),
      );
      expect(
        (first
                as Ok<
                  WalletTransactionSyncOutcome,
                  WalletTransactionSyncFailure
                >)
            .value
            .snapshot
            .revision,
        1,
      );
      source.next = WalletSourceObservation(
        key: key,
        registration: registration,
        transactions: [
          WalletTransaction(
            txid: 'a',
            amountSats: 10,
            position: UnconfirmedPosition(DateTime(2020), DateTime(2021)),
          ),
        ],
      );
      final changed = await facade.synchronizeWallet(
        SynchronizeWalletRequest(registration),
      );
      expect(
        (changed
                as Ok<
                  WalletTransactionSyncOutcome,
                  WalletTransactionSyncFailure
                >)
            .value
            .snapshot
            .revision,
        2,
      );
    },
  );

  test(
    'delete is idempotent and deleted keys revive only through discovery',
    () async {
      final source = FakeSource();
      final facade = build(source, FakeMetadata());
      expect(
        await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
        isA<Ok>(),
      );
      expect(await facade.deleteWallet(key), isA<Ok>());
      expect(await facade.deleteWallet(key), isA<Ok>());
      expect(
        await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
        isA<Err>(),
      );
      expect(
        await facade.synchronizeWallet(SynchronizeWalletRequest(registration)),
        isA<Err>(),
      );
      expect(
        await facade.discoverWalletHistory(
          DiscoverWalletHistoryRequest(registration),
        ),
        isA<Ok>(),
      );
    },
  );

  test(
    'source state missing is surfaced without silently rebuilding',
    () async {
      final source = FakeSource()
        ..failure = const WalletSourceStateMissingFailure();
      final facade = build(source, FakeMetadata());
      final result = await facade.refreshLocalSnapshot(
        RefreshLocalSnapshotRequest(registration),
      );
      expect(result, isA<Err>());
      expect((result as Err).failure, isA<WalletSourceStateMissingFailure>());
    },
  );
}
