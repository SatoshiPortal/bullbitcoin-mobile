import 'package:test/test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

import 'support/fakes.dart';

void main() {
  test('warning state exposes process-local observation explicitly', () {
    final observed = DateTime(2020);
    final state = WalletStateReadyWithWarning(
      3,
      observed,
      const MetadataPersistenceWarning(),
    );
    expect(state.nonDurableObservedAt, observed);
    expect(state.freshness, isNull);
    expect(state.revision, 3);
  });

  test('a new subscriber receives the current state first', () async {
    final facade = buildFacade(RecordingSource(), RecordingMetadata());
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );
    final states = <WalletTransactionSyncState>[];
    final subscription = facade.watchWalletState(testKey).listen(states.add);
    await Future<void>.delayed(Duration.zero);
    expect(states.single, isA<WalletStateReady>());
    expect((states.single as WalletStateReady).revision, 1);
    await subscription.cancel();
  });

  test(
    'no transition is lost when an operation starts in the listen turn',
    () async {
      final facade = buildFacade(RecordingSource(), RecordingMetadata());
      okValue(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );
      final states = <WalletTransactionSyncState>[];
      final subscription = facade.watchWalletState(testKey).listen(states.add);
      final sync = facade.synchronizeWallet(
        const SynchronizeWalletRequest(testRegistration),
      );
      okValue(await sync);
      await Future<void>.delayed(Duration.zero);
      expect(states.first, isA<WalletStateReady>());
      expect(states.whereType<WalletStateSyncing>(), hasLength(1));
      expect(states.last, isA<WalletStateReady>());
      expect(
        (states.whereType<WalletStateSyncing>().single).previousRevision,
        1,
      );
      await subscription.cancel();
    },
  );

  test('a consumer re-reads exactly once per new ready revision', () async {
    final source = RecordingSource();
    final facade = buildFacade(source, RecordingMetadata());
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );

    final readRevisions = <int>[];
    final subscription = facade.watchWalletState(testKey).listen((state) {
      if (state is WalletStateReady) readRevisions.add(state.revision);
    });

    // Same content: no new revision, freshness-only update.
    okValue(
      await facade.synchronizeWallet(
        const SynchronizeWalletRequest(testRegistration),
      ),
    );
    // Failed sync: no ready state at all.
    source.failure = const SourceFailure(SourceFailureReason.unavailable);
    expect(
      errFailure(
        await facade.synchronizeWallet(
          const SynchronizeWalletRequest(testRegistration),
        ),
      ),
      isA<SourceFailure>(),
    );
    // Changed content: exactly one new revision.
    source
      ..failure = null
      ..observationBuilder = (registration) => WalletSourceObservation(
        key: registration.key,
        registration: registration,
        transactions: [
          WalletTransaction(
            txid: 'a',
            amountSats: 10,
            position: UnconfirmedPosition(
              DateTime.utc(2026),
              DateTime.utc(2026),
            ),
          ),
        ],
      );
    okValue(
      await facade.synchronizeWallet(
        const SynchronizeWalletRequest(testRegistration),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final distinctRevisions = readRevisions.toSet();
    expect(distinctRevisions, {1, 2});
    expect(
      readRevisions.where((revision) => revision == 2),
      hasLength(1),
      reason: 'one changed sync must produce exactly one new ready revision',
    );
    await subscription.cancel();
  });

  test(
    'readyWithWarning carries the observation time through the facade',
    () async {
      final metadata = RecordingMetadata();
      final clock = DateTime.utc(2026, 8, 29, 12);
      final facade = WalletTransactionSyncFacade(
        source: RecordingSource(),
        metadata: metadata,
        coordinator: InMemoryWalletSourceOperationCoordinator(),
        now: () => clock,
      );
      final states = <WalletTransactionSyncState>[];
      final subscription = facade.watchWalletState(testKey).listen(states.add);

      metadata.failSuccess = true;
      final outcome = okValue(
        await facade.synchronizeWallet(
          const SynchronizeWalletRequest(testRegistration),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(outcome.warning, isA<MetadataPersistenceWarning>());
      expect(outcome.snapshot.lastSuccessfulSyncAt, isNull);
      final warningState = states
          .whereType<WalletStateReadyWithWarning>()
          .single;
      expect(warningState.nonDurableObservedAt, clock);
      expect(warningState.freshness, isNull);
      await subscription.cancel();
    },
  );
}
