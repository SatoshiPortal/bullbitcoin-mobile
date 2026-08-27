import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_coordinator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('coalesces concurrent publication and drains one queued pass', () async {
    final first = Completer<Result<void, WalletBackupFailure>>();
    var publishCalls = 0;
    final coordinator = WalletBackupCoordinator(
      manifestChanges: const Stream.empty(),
      syncResults: const Stream.empty(),
      publishBackup: () {
        publishCalls++;
        if (publishCalls == 1) return first.future;
        return Future.value(const Ok(null));
      },
      markDirty: () async => const Ok(null),
    );

    final firstRequest = coordinator.publish();
    final concurrentRequest = coordinator.publish();

    expect(publishCalls, 1);
    expect(identical(firstRequest, concurrentRequest), isTrue);

    first.complete(const Ok(null));
    expect(await firstRequest, isA<Ok<void, WalletBackupFailure>>());
    expect(publishCalls, 2);
  });

  test('waitForIdle holds deletion behind an active publication', () async {
    final publication = Completer<Result<void, WalletBackupFailure>>();
    final coordinator = WalletBackupCoordinator(
      manifestChanges: const Stream.empty(),
      syncResults: const Stream.empty(),
      publishBackup: () => publication.future,
      markDirty: () async => const Ok(null),
    );

    final publishing = coordinator.publish();
    var idleReached = false;
    final waiting = coordinator.waitForIdle().then((_) => idleReached = true);
    await pumpEventQueue();
    expect(idleReached, isFalse);

    publication.complete(const Ok(null));
    await publishing;
    await waiting;
    expect(idleReached, isTrue);
  });

  test('explicit publication marks the latest state dirty first', () async {
    var dirtyRevision = 0;
    final capturedRevisions = <int>[];
    final coordinator = WalletBackupCoordinator(
      manifestChanges: const Stream.empty(),
      syncResults: const Stream.empty(),
      publishBackup: () async {
        capturedRevisions.add(dirtyRevision);
        return const Ok(null);
      },
      markDirty: () async {
        dirtyRevision++;
        return const Ok(null);
      },
    );

    expect(
      await coordinator.publishLatest(),
      isA<Ok<void, WalletBackupFailure>>(),
    );
    expect(capturedRevisions, [1]);
  });

  test(
    'explicit publication queues latest state behind an older in-flight pass',
    () async {
      final first = Completer<Result<void, WalletBackupFailure>>();
      var dirtyRevision = 0;
      final capturedRevisions = <int>[];
      final coordinator = WalletBackupCoordinator(
        manifestChanges: const Stream.empty(),
        syncResults: const Stream.empty(),
        publishBackup: () {
          capturedRevisions.add(dirtyRevision);
          if (capturedRevisions.length == 1) return first.future;
          return Future.value(const Ok(null));
        },
        markDirty: () async {
          dirtyRevision++;
          return const Ok(null);
        },
      );

      final olderPublication = coordinator.publish();
      final latestPublication = coordinator.publishLatest();
      await pumpEventQueue();
      expect(capturedRevisions, [0]);

      first.complete(const Ok(null));
      expect(await latestPublication, isA<Ok<void, WalletBackupFailure>>());
      await olderPublication;
      expect(capturedRevisions, [0, 1]);
    },
  );

  test('clears queue ownership before completing waiting callers', () async {
    final first = Completer<Result<void, WalletBackupFailure>>();
    var publishCalls = 0;
    final coordinator = WalletBackupCoordinator(
      manifestChanges: const Stream.empty(),
      syncResults: const Stream.empty(),
      publishBackup: () {
        publishCalls++;
        if (publishCalls == 1) return first.future;
        return Future.value(const Ok(null));
      },
      markDirty: () async => const Ok(null),
    );

    final firstRequest = coordinator.publish();
    final afterCompletion = firstRequest.then((_) => coordinator.publish());

    first.complete(const Ok(null));
    await afterCompletion;

    expect(publishCalls, 2);
  });

  test(
    'defers publication requests until recovery releases its lease',
    () async {
      var publishCalls = 0;
      final coordinator = WalletBackupCoordinator(
        manifestChanges: const Stream.empty(),
        syncResults: const Stream.empty(),
        publishBackup: () async {
          publishCalls++;
          return const Ok(null);
        },
        markDirty: () async => const Ok(null),
      );

      final lease = await coordinator.beginRecoveryLease();
      final publication = coordinator.publish();
      await pumpEventQueue();
      expect(publishCalls, 0);

      lease.close();
      await publication;
      expect(publishCalls, 1);
      await coordinator.dispose();
    },
  );

  test(
    'rolls back a recovery lease when the active publication fails',
    () async {
      var publishCalls = 0;
      final coordinator = WalletBackupCoordinator(
        manifestChanges: const Stream.empty(),
        syncResults: const Stream.empty(),
        publishBackup: () async {
          publishCalls++;
          if (publishCalls == 1) {
            throw StateError('publication failed');
          }
          return const Ok(null);
        },
        markDirty: () async => const Ok(null),
      );

      await expectLater(coordinator.publish(), throwsA(isA<StateError>()));
      final lease = await coordinator.beginRecoveryLease();
      lease.close();
      await pumpEventQueue();
      expect(publishCalls, 2);

      await coordinator.publish();
      expect(publishCalls, 3);
      await coordinator.dispose();
    },
  );

  test(
    'failed lease acquisition drains publications deferred behind it',
    () async {
      final first = Completer<Result<void, WalletBackupFailure>>();
      var publishCalls = 0;
      final coordinator = WalletBackupCoordinator(
        manifestChanges: const Stream.empty(),
        syncResults: const Stream.empty(),
        publishBackup: () {
          publishCalls++;
          if (publishCalls == 1) return first.future;
          return Future.value(const Ok(null));
        },
        markDirty: () async => const Ok(null),
      );

      final activePublication = coordinator.publish();
      final acquisition = coordinator.beginRecoveryLease();
      final deferredPublication = coordinator.publish();
      await pumpEventQueue();
      expect(publishCalls, 1);

      final activeFailure = expectLater(
        activePublication,
        throwsA(isA<StateError>()),
      );
      final acquisitionFailure = expectLater(
        acquisition,
        throwsA(isA<StateError>()),
      );
      first.completeError(StateError('publication failed'));
      await activeFailure;
      await acquisitionFailure;
      expect(await deferredPublication, isA<Ok<void, WalletBackupFailure>>());
      expect(publishCalls, 2);
      await coordinator.dispose();
    },
  );

  test(
    'dispose completes deferred publications when the active pass throws',
    () async {
      final publication = Completer<Result<void, WalletBackupFailure>>();
      final coordinator = WalletBackupCoordinator(
        manifestChanges: const Stream.empty(),
        syncResults: const Stream.empty(),
        publishBackup: () => publication.future,
        markDirty: () async => const Ok(null),
      );

      final active = expectLater(
        coordinator.publish(),
        throwsA(isA<StateError>()),
      );
      final lease = expectLater(
        coordinator.beginRecoveryLease(),
        throwsA(isA<StateError>()),
      );
      final deferred = coordinator.publish();
      final disposing = coordinator.dispose();

      publication.completeError(StateError('publication failed'));

      await active;
      await lease;
      await expectLater(disposing, completes);
      final deferredResult = await deferred;
      expect(
        deferredResult,
        isA<Err<void, WalletBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletBackupUnexpectedFailure>(),
        ),
      );
    },
  );

  test('deletion lease waits until recovery releases ownership', () async {
    final coordinator = WalletBackupCoordinator(
      manifestChanges: const Stream.empty(),
      syncResults: const Stream.empty(),
      publishBackup: () async => const Ok(null),
      markDirty: () async => const Ok(null),
    );

    final recovery = await coordinator.beginRecoveryLease();
    var deletionAcquired = false;
    final deletionFuture = coordinator.beginDeletionLease().then((lease) {
      deletionAcquired = true;
      return lease;
    });
    await pumpEventQueue();
    expect(deletionAcquired, isFalse);

    recovery.close();
    final deletion = await deletionFuture;
    expect(deletionAcquired, isTrue);
    deletion.close();
    await coordinator.dispose();
  });

  test(
    'timed-out lease acquisition does not strand the lifecycle queue',
    () async {
      final publication = Completer<Result<void, WalletBackupFailure>>();
      var publishCalls = 0;
      final coordinator = WalletBackupCoordinator(
        manifestChanges: const Stream.empty(),
        syncResults: const Stream.empty(),
        publishBackup: () {
          publishCalls++;
          return publishCalls == 1
              ? publication.future
              : Future.value(const Ok(null));
        },
        markDirty: () async => const Ok(null),
      );

      final activePublication = coordinator.publish();
      await expectLater(
        coordinator.beginRecoveryLease(
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );

      publication.complete(const Ok(null));
      await activePublication;
      final laterLease = await coordinator.beginRecoveryLease();
      laterLease.close();
      await coordinator.dispose();
    },
  );

  testWidgets(
    'a manifest change during publication dirties and queues a second pass',
    (tester) async {
      final manifestChanges = StreamController<void>.broadcast();
      final syncResults = StreamController<ElectrumSyncResult>.broadcast();
      final first = Completer<Result<void, WalletBackupFailure>>();
      var dirtyRevision = 0;
      final capturedRevisions = <int>[];
      final coordinator = WalletBackupCoordinator(
        manifestChanges: manifestChanges.stream,
        syncResults: syncResults.stream,
        publishBackup: () {
          capturedRevisions.add(dirtyRevision);
          if (capturedRevisions.length == 1) return first.future;
          return Future.value(const Ok(null));
        },
        markDirty: () async {
          dirtyRevision++;
          return const Ok(null);
        },
      );
      addTearDown(manifestChanges.close);
      addTearDown(syncResults.close);
      addTearDown(coordinator.dispose);

      coordinator.start();
      await tester.pump();
      expect(capturedRevisions, [0]);

      manifestChanges.add(null);
      await tester.pump();
      expect(dirtyRevision, 1);
      expect(capturedRevisions, [0]);

      first.complete(const Ok(null));
      await tester.pump();
      expect(capturedRevisions, [0, 1]);
    },
  );

  testWidgets('retries on startup, resume, and successful sync only', (
    tester,
  ) async {
    final manifestChanges = StreamController<void>.broadcast();
    final syncResults = StreamController<ElectrumSyncResult>.broadcast();
    var publishCalls = 0;
    final coordinator = WalletBackupCoordinator(
      manifestChanges: manifestChanges.stream,
      syncResults: syncResults.stream,
      publishBackup: () async {
        publishCalls++;
        return const Ok(null);
      },
      markDirty: () async => const Ok(null),
    );
    addTearDown(manifestChanges.close);
    addTearDown(syncResults.close);
    addTearDown(coordinator.dispose);

    coordinator.start();
    await tester.pump();
    expect(publishCalls, 1);

    syncResults.add(const ElectrumSyncResult(isLiquid: false, success: false));
    await tester.pump();
    expect(publishCalls, 1);

    syncResults.add(const ElectrumSyncResult(isLiquid: false, success: true));
    await tester.pump();
    expect(publishCalls, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(publishCalls, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(publishCalls, 3);
  });

  testWidgets('a failed dirty write retries on the next normal trigger', (
    tester,
  ) async {
    final manifestChanges = StreamController<void>.broadcast();
    final syncResults = StreamController<ElectrumSyncResult>.broadcast();
    var publishCalls = 0;
    var dirtyCalls = 0;
    final coordinator = WalletBackupCoordinator(
      manifestChanges: manifestChanges.stream,
      syncResults: syncResults.stream,
      publishBackup: () async {
        publishCalls++;
        return const Ok(null);
      },
      markDirty: () async {
        dirtyCalls++;
        if (dirtyCalls == 1) {
          return const Err(WalletBackupStorageFailure());
        }
        return const Ok(null);
      },
    );
    addTearDown(manifestChanges.close);
    addTearDown(syncResults.close);
    addTearDown(coordinator.dispose);

    coordinator.start();
    await tester.pump();
    expect(publishCalls, 1);

    manifestChanges.add(null);
    await tester.pump();
    expect(dirtyCalls, 1);
    expect(publishCalls, 1);

    syncResults.add(const ElectrumSyncResult(isLiquid: false, success: true));
    await tester.pump();
    expect(dirtyCalls, 2);
    expect(publishCalls, 2);
  });

  test('dispose fences a blocked dirty task from publication', () async {
    final manifestChanges = StreamController<void>.broadcast();
    final dirty = Completer<Result<void, WalletBackupFailure>>();
    var publishCalls = 0;
    final coordinator = WalletBackupCoordinator(
      manifestChanges: manifestChanges.stream,
      syncResults: const Stream.empty(),
      publishBackup: () async {
        publishCalls++;
        return const Ok(null);
      },
      markDirty: () => dirty.future,
    );
    addTearDown(manifestChanges.close);
    addTearDown(coordinator.dispose);

    coordinator.start();
    await coordinator.waitForIdle();
    expect(publishCalls, 1);

    manifestChanges.add(null);
    await pumpEventQueue();
    final disposing = coordinator.dispose();
    dirty.complete(const Ok(null));
    await disposing;

    expect(publishCalls, 1);
  });
}
