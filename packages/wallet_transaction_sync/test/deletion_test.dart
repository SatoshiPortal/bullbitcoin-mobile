import 'dart:async';

import 'package:test/test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

import 'support/fakes.dart';

void main() {
  test(
    'failed source delete leaves the marker and resumes on next call',
    () async {
      final source = RecordingSource()..deleteFailuresRemaining = 1;
      final metadata = RecordingMetadata();
      final facade = buildFacade(source, metadata);
      okValue(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );

      final failed = await facade.deleteWallet(testKey);
      expect(errFailure(failed), isA<DeletionFailure>());
      expect(source.deleteCalls, 1);
      expect(metadata.values[testKey]?.deletionPending, isTrue);

      final resumed = await facade.synchronizeWallet(
        const SynchronizeWalletRequest(testRegistration),
      );
      expect(errFailure(resumed), isA<DeletedWalletFailure>());
      expect(source.deleteCalls, 2);
      expect(metadata.values[testKey], isNull);
      expect(metadata.receipts[testKey], isNull);
    },
  );

  test(
    'discover resumes a pending deletion and then revives the key',
    () async {
      final source = RecordingSource()..deleteFailuresRemaining = 1;
      final metadata = RecordingMetadata();
      final facade = buildFacade(source, metadata);
      okValue(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );
      expect(
        errFailure(await facade.deleteWallet(testKey)),
        isA<DeletionFailure>(),
      );

      final revived = await facade.discoverWalletHistory(
        const DiscoverWalletHistoryRequest(testRegistration),
      );
      expect(okValue(revived).snapshot.revision, greaterThan(0));
      expect(source.deleteCalls, 2);
      expect(metadata.values[testKey]?.deletionPending, isNot(isTrue));
    },
  );

  test(
    'delete waits for an in-flight sync and nothing is published after deleted',
    () async {
      final source = RecordingSource();
      final metadata = RecordingMetadata();
      final facade = buildFacade(source, metadata);
      okValue(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );

      final states = <WalletTransactionSyncState>[];
      final subscription = facade.watchWalletState(testKey).listen(states.add);

      final release = Completer<void>();
      final entered = Completer<void>();
      source
        ..pauseSync = release
        ..syncEntered = entered;
      final sync = facade.synchronizeWallet(
        const SynchronizeWalletRequest(testRegistration),
      );
      await entered.future;

      final deletion = facade.deleteWallet(testKey);
      await Future<void>.delayed(Duration.zero);
      expect(source.deleteCalls, 0, reason: 'delete must wait for the sync');

      release.complete();
      okValue(await sync);
      okValue(await deletion);
      await Future<void>.delayed(Duration.zero);

      expect(states.last, isA<WalletStateDeleted>());
      final deletedIndex = states.indexWhere((s) => s is WalletStateDeleted);
      expect(
        states.skip(deletedIndex + 1).whereType<WalletStateReady>(),
        isEmpty,
        reason: 'no snapshot may be published after deleted',
      );
      expect(
        errFailure(
          await facade.lookupLocal(
            const LookupLocalTransactionRequest(testKey, 'a'),
          ),
        ),
        isA<SnapshotNotInitializedFailure>(),
      );
      await subscription.cancel();
    },
  );

  test(
    'discover with a replacement registration revives after a resumed deletion',
    () async {
      final source = RecordingSource()..deleteFailuresRemaining = 1;
      final metadata = RecordingMetadata();
      final facade = buildFacade(source, metadata);
      metadata.values[testKey] = const WalletSyncMetadata(
        registration: testRegistration,
      );
      okValue(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );
      expect(
        errFailure(await facade.deleteWallet(testKey)),
        isA<DeletionFailure>(),
      );

      const replacement = WalletSourceRegistration(
        key: testKey,
        sourceKind: 'fake',
        configurationFingerprint: 'replacement',
      );
      final revived = await facade.discoverWalletHistory(
        const DiscoverWalletHistoryRequest(replacement),
      );
      expect(
        okValue(revived).snapshot.revision,
        greaterThan(0),
        reason: 'the old registration died with the resumed deletion',
      );
    },
  );

  test('successful package deletion retires its source key', () async {
    final source = RecordingSource();
    final metadata = RecordingMetadata();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    final facade = WalletTransactionSyncFacade(
      source: source,
      metadata: metadata,
      coordinator: coordinator,
    );
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );

    okValue(await facade.deleteWallet(testKey));

    await expectLater(
      coordinator.runExclusive(
        const WalletSourceKey('w', 'bitcoin', 'testnet'),
        (_) async {},
      ),
      throwsStateError,
    );
  });

  test(
    'metadata clear failure does not strand package deletion retirement',
    () async {
      final source = RecordingSource();
      final metadata = RecordingMetadata()..clearFailuresRemaining = 1;
      final coordinator = InMemoryWalletSourceOperationCoordinator();
      final facade = WalletTransactionSyncFacade(
        source: source,
        metadata: metadata,
        coordinator: coordinator,
      );
      okValue(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );

      expect(
        errFailure(await facade.deleteWallet(testKey)),
        isA<DeletionFailure>(),
      );
      expect(
        await coordinator.runExclusive(
          const WalletSourceKey('w', 'bitcoin', 'testnet'),
          (_) async => true,
        ),
        isTrue,
      );
      okValue(await facade.deleteWallet(testKey));
      await expectLater(
        coordinator.runExclusive(
          const WalletSourceKey('w', 'bitcoin', 'testnet'),
          (_) async {},
        ),
        throwsStateError,
      );
    },
  );

  test(
    'successful discovery reactivates after source reconstruction',
    () async {
      final source = RecordingSource();
      final metadata = RecordingMetadata();
      final coordinator = InMemoryWalletSourceOperationCoordinator();
      final facade = WalletTransactionSyncFacade(
        source: source,
        metadata: metadata,
        coordinator: coordinator,
      );
      okValue(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );
      okValue(await facade.deleteWallet(testKey));

      okValue(
        await facade.discoverWalletHistory(
          const DiscoverWalletHistoryRequest(testRegistration),
        ),
      );
      expect(
        await coordinator.runExclusive(
          const WalletSourceKey('w', 'bitcoin', 'testnet'),
          (_) async => true,
        ),
        isTrue,
      );
    },
  );

  test(
    'failed discovery leaves a successfully deleted source retired',
    () async {
      final source = RecordingSource();
      final metadata = RecordingMetadata();
      final coordinator = InMemoryWalletSourceOperationCoordinator();
      final facade = WalletTransactionSyncFacade(
        source: source,
        metadata: metadata,
        coordinator: coordinator,
      );
      okValue(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );
      okValue(await facade.deleteWallet(testKey));
      source.failure = const DeletionFailure();

      expect(
        errFailure(
          await facade.discoverWalletHistory(
            const DiscoverWalletHistoryRequest(testRegistration),
          ),
        ),
        isA<DeletionFailure>(),
      );
      await expectLater(
        coordinator.runExclusive(
          const WalletSourceKey('w', 'bitcoin', 'testnet'),
          (_) async {},
        ),
        throwsStateError,
      );
    },
  );

  test(
    'mismatched discovery leaves a successfully deleted source retired',
    () async {
      final source = RecordingSource();
      final metadata = RecordingMetadata();
      final coordinator = InMemoryWalletSourceOperationCoordinator();
      final facade = WalletTransactionSyncFacade(
        source: source,
        metadata: metadata,
        coordinator: coordinator,
      );
      okValue(
        await facade.refreshLocalSnapshot(
          const RefreshLocalSnapshotRequest(testRegistration),
        ),
      );
      okValue(await facade.deleteWallet(testKey));
      source.observationBuilder = (registration) => WalletSourceObservation(
        key: const WalletNetworkKey('other', 'bitcoin', 'testnet'),
        registration: registration,
        transactions: const [],
      );

      expect(
        errFailure(
          await facade.discoverWalletHistory(
            const DiscoverWalletHistoryRequest(testRegistration),
          ),
        ),
        isA<SourceObservationMismatchFailure>(),
      );
      await expectLater(
        coordinator.runExclusive(
          const WalletSourceKey('w', 'bitcoin', 'testnet'),
          (_) async {},
        ),
        throwsStateError,
      );
    },
  );

  test('second delete after completion is an idempotent success', () async {
    final source = RecordingSource();
    final facade = buildFacade(source, RecordingMetadata());
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );
    okValue(await facade.deleteWallet(testKey));
    final deleteCallsAfterFirst = source.deleteCalls;
    okValue(await facade.deleteWallet(testKey));
    expect(source.deleteCalls, deleteCallsAfterFirst);
  });

  test('deletion completes existing watchers and stays replayable', () async {
    final facade = buildFacade(RecordingSource(), RecordingMetadata());
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );
    final states = <WalletTransactionSyncState>[];
    var done = false;
    facade
        .watchWalletState(testKey)
        .listen(states.add, onDone: () => done = true);
    await Future<void>.delayed(Duration.zero);

    okValue(await facade.deleteWallet(testKey));
    await Future<void>.delayed(Duration.zero);
    expect(states.last, isA<WalletStateDeleted>());
    expect(done, isTrue, reason: 'the stream of a deleted key must complete');

    final lateStates = <WalletTransactionSyncState>[];
    final lateSubscription = facade
        .watchWalletState(testKey)
        .listen(lateStates.add);
    await Future<void>.delayed(Duration.zero);
    expect(lateStates.single, isA<WalletStateDeleted>());
    await lateSubscription.cancel();
  });

  test('dispose completes every watcher stream', () async {
    final facade = buildFacade(RecordingSource(), RecordingMetadata());
    okValue(
      await facade.refreshLocalSnapshot(
        const RefreshLocalSnapshotRequest(testRegistration),
      ),
    );
    var done = false;
    facade.watchWalletState(testKey).listen((_) {}, onDone: () => done = true);
    await Future<void>.delayed(Duration.zero);
    await facade.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
  });
}
