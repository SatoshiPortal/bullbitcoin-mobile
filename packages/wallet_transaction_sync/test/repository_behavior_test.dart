import 'dart:async';

import 'package:test/test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

import 'support/fakes.dart';

void main() {
  test(
    'concurrent local initialization shares one source reconstruction',
    () async {
      final source = RecordingSource();
      final facade = buildFacade(source, RecordingMetadata());
      final release = Completer<void>();
      final entered = Completer<void>();
      source
        ..pauseRefresh = release
        ..refreshEntered = entered;
      final states = <WalletTransactionSyncState>[];
      final subscription = facade.watchWalletState(testKey).listen(states.add);

      final refreshes = List.generate(
        10,
        (_) => facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );
      await entered.future;
      expect(source.refreshCalls, 1);
      release.complete();

      final outcomes = (await Future.wait(refreshes)).map(okValue).toList();
      expect(source.refreshCalls, 1);
      expect(
        outcomes.skip(1).map((outcome) => outcome.snapshot),
        everyElement(same(outcomes.first.snapshot)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(states.whereType<WalletStateLoadingLocal>(), hasLength(1));
      expect(states.whereType<WalletStateReady>(), hasLength(1));
      await subscription.cancel();
    },
  );

  test('a failed shared local initialization can be retried', () async {
    final source = RecordingSource()
      ..failure = const SourceFailure(SourceFailureReason.unavailable);
    final facade = buildFacade(source, RecordingMetadata());
    final release = Completer<void>();
    final entered = Completer<void>();
    source
      ..pauseRefresh = release
      ..refreshEntered = entered;

    final refreshes = List.generate(
      5,
      (_) => facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );
    await entered.future;
    release.complete();
    final failures = (await Future.wait(refreshes)).map(errFailure).toList();

    expect(source.refreshCalls, 1);
    expect(failures, everyElement(isA<SourceFailure>()));
    source.failure = null;
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );
    expect(source.refreshCalls, 2);
  });

  test('different registrations do not share a local initialization', () async {
    final source = RecordingSource();
    final facade = buildFacade(source, RecordingMetadata());
    final release = Completer<void>();
    final entered = Completer<void>();
    source
      ..pauseRefresh = release
      ..refreshEntered = entered;
    const otherRegistration = WalletSourceRegistration(
      key: testKey,
      sourceKind: 'fake',
      configurationFingerprint: 'other',
    );

    final first = facade.refreshLocalSnapshot(
      const RefreshLocalSnapshotRequest(testRegistration),
    );
    await entered.future;
    final second = facade.refreshLocalSnapshot(
      const RefreshLocalSnapshotRequest(otherRegistration),
    );
    release.complete();
    okValue(await first);
    okValue(await second);

    expect(source.refreshCalls, 2);
  });

  test(
    'the previous revision stays readable during an in-flight sync',
    () async {
      final source = RecordingSource();
      final facade = buildFacade(source, RecordingMetadata());
      okValue(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );

      final release = Completer<void>();
      final entered = Completer<void>();
      source
        ..pauseSync = release
        ..syncEntered = entered;
      final sync = facade.synchronizeWallet(
        const SynchronizeWalletRequest(testRegistration),
      );
      await entered.future;

      final page = okValue(
        await facade.listLocal(const ListLocalTransactionsRequest(testKey)),
      );
      expect(page.revision, 1);
      expect(page.items.single.transaction.txid, 'a');

      release.complete();
      okValue(await sync);
    },
  );

  test('a failed sync leaves the durable freshness value untouched', () async {
    final source = RecordingSource();
    final clock = DateTime.utc(2026, 8, 29, 10);
    final facade = WalletTransactionSyncFacade(
      source: source,
      metadata: RecordingMetadata(),
      coordinator: InMemoryWalletSourceOperationCoordinator(),
      now: () => clock,
    );
    final synced = okValue(
      await facade.synchronizeWallet(
        const SynchronizeWalletRequest(testRegistration),
      ),
    );
    expect(synced.snapshot.lastSuccessfulSyncAt, clock);

    final states = <WalletTransactionSyncState>[];
    final subscription = facade.watchWalletState(testKey).listen(states.add);
    source.failure = const SourceFailure(SourceFailureReason.unavailable);
    expect(
      errFailure(
        await facade.synchronizeWallet(
          const SynchronizeWalletRequest(testRegistration),
        ),
      ),
      isA<SourceFailure>(),
    );
    await Future<void>.delayed(Duration.zero);

    final failed = states.whereType<WalletStateFailed>().single;
    expect(failed.previousRevision, 1);
    expect(failed.freshness, clock);
    final observation = okValue(
      await facade.lookupLocal(
        const LookupLocalTransactionRequest(testKey, 'a'),
      ),
    );
    expect(observation!.lastSuccessfulSyncAt, clock);
    await subscription.cancel();
  });

  test('a mid-mapping failure leaves no partial state behind', () async {
    final source = RecordingSource();
    final facade = buildFacade(source, RecordingMetadata());
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );

    // A non-encodable detail value makes the canonical fingerprint throw
    // after the observation has already been partially processed.
    source.observationBuilder = (registration) => WalletSourceObservation(
      key: registration.key,
      registration: registration,
      transactions: [
        WalletTransaction(
          txid: 'poison',
          amountSats: 1,
          position: const UnknownPosition(),
          details: {'bad': Object()},
        ),
      ],
    );
    expect(
      errFailure(
        await facade.synchronizeWallet(
          const SynchronizeWalletRequest(testRegistration),
        ),
      ),
      isA<WalletTransactionSyncFailure>(),
    );

    final page = okValue(
      await facade.listLocal(const ListLocalTransactionsRequest(testKey)),
    );
    expect(page.revision, 1);
    expect(page.items.single.transaction.txid, 'a');
    expect(
      okValue(
        await facade.lookupLocal(
          const LookupLocalTransactionRequest(testKey, 'poison'),
        ),
      ),
      isNull,
    );
  });

  test(
    'reconstruction attaches durable freshness only on a matching receipt',
    () async {
      final metadata = RecordingMetadata();
      final syncClock = DateTime.utc(2026, 8, 29, 9);
      final syncFacade = WalletTransactionSyncFacade(
        source: RecordingSource(),
        metadata: metadata,
        coordinator: InMemoryWalletSourceOperationCoordinator(),
        now: () => syncClock,
      );
      okValue(
        await syncFacade.synchronizeWallet(
          const SynchronizeWalletRequest(testRegistration),
        ),
      );
      expect(metadata.receipts[testKey], isNotNull);

      // Same durable metadata, new process: same content matches the receipt.
      final restartedFacade = buildFacade(RecordingSource(), metadata);
      final matching = okValue(
        await restartedFacade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );
      expect(matching.snapshot.lastSuccessfulSyncAt, syncClock);

      // New process again, but the source now reports different content.
      final changedSource = RecordingSource()
        ..observationBuilder = (registration) => WalletSourceObservation(
          key: registration.key,
          registration: registration,
          transactions: [
            WalletTransaction(
              txid: 'other',
              amountSats: 3,
              position: const UnknownPosition(),
            ),
          ],
        );
      final divergedFacade = buildFacade(changedSource, metadata);
      final diverged = okValue(
        await divergedFacade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );
      expect(
        diverged.snapshot.lastSuccessfulSyncAt,
        isNull,
        reason: 'an old receipt must not date newer content',
      );
    },
  );

  test('an observation for another key or registration is rejected', () async {
    const foreignKey = WalletNetworkKey('other', 'bitcoin', 'testnet');
    final lyingSource = RecordingSource()
      ..observationBuilder = (registration) => WalletSourceObservation(
        key: foreignKey,
        registration: const WalletSourceRegistration(
          key: foreignKey,
          sourceKind: 'fake',
          configurationFingerprint: 'one',
        ),
        transactions: const [],
      );
    final facade = buildFacade(lyingSource, RecordingMetadata());
    expect(
      errFailure(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      ),
      isA<SourceObservationMismatchFailure>(),
    );
    expect(
      errFailure(
        await facade.lookupLocal(
          const LookupLocalTransactionRequest(testKey, 'a'),
        ),
      ),
      isA<SnapshotNotInitializedFailure>(),
      reason: 'a mismatched observation must not be published',
    );
  });

  test(
    'a conflicting registration fails typed and keeps the snapshot readable',
    () async {
      final metadata = RecordingMetadata();
      final facade = buildFacade(RecordingSource(), metadata);
      okValue(
        await facade.synchronizeWallet(
          const SynchronizeWalletRequest(testRegistration),
        ),
      );
      metadata.values[testKey] = const WalletSyncMetadata(
        registration: testRegistration,
      );

      const conflicting = WalletSourceRegistration(
        key: testKey,
        sourceKind: 'fake',
        configurationFingerprint: 'two',
      );
      expect(
        errFailure(
          await facade.synchronizeWallet(
            const SynchronizeWalletRequest(conflicting),
          ),
        ),
        isA<WalletRegistrationMismatchFailure>(),
      );
      final page = okValue(
        await facade.listLocal(const ListLocalTransactionsRequest(testKey)),
      );
      expect(page.revision, 1);
    },
  );

  test('a missing transaction is an absence, not a failure', () async {
    final facade = buildFacade(RecordingSource(), RecordingMetadata());
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );
    expect(
      okValue(
        await facade.lookupLocal(
          const LookupLocalTransactionRequest(testKey, 'unknown-txid'),
        ),
      ),
      isNull,
    );
  });

  test('published snapshots are deeply immutable', () async {
    final nestedEvidence = <String, Object?>{
      'chain': <String, Object?>{'depth': 1},
    };
    final transactions = <WalletTransaction>[
      WalletTransaction(
        txid: 'a',
        amountSats: 10,
        position: const UnknownPosition(),
        evidence: nestedEvidence,
      ),
    ];
    final source = RecordingSource()
      ..observationBuilder = (registration) => WalletSourceObservation(
        key: registration.key,
        registration: registration,
        transactions: transactions,
      );
    final facade = buildFacade(source, RecordingMetadata());
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );

    final observation = okValue(
      await facade.lookupLocal(
        const LookupLocalTransactionRequest(testKey, 'a'),
      ),
    )!;
    expect(
      () => observation.transaction.evidence['chain'] = 'tampered',
      throwsUnsupportedError,
    );
    expect(
      () =>
          (observation.transaction.evidence['chain']!
                  as Map<String, Object?>)['depth'] =
              2,
      throwsUnsupportedError,
    );

    final page = okValue(
      await facade.listLocal(const ListLocalTransactionsRequest(testKey)),
    );
    expect(() => page.items.clear(), throwsUnsupportedError);
  });
}
