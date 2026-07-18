import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_publish_outcome.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_recovery_plan.dart'
    as internal;
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/delete_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/get_wallet_metadata_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/mark_wallet_metadata_backup_dirty_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/set_wallet_metadata_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_key_material_port.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_publication_guard.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart'
    show WalletMetadataBackupFacade;
import 'package:bb_mobile/features/wallet_metadata_backup/watchers/wallet_metadata_backup_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<void> changes;
  late StreamController<void> syncs;
  late _StateRepository states;
  late WalletMetadataPublicationGuard guard;
  late WalletMetadataBackupCoordinator coordinator;
  var publishes = 0;

  setUp(() {
    publishes = 0;
    changes = StreamController<void>.broadcast();
    syncs = StreamController<void>.broadcast();
    states = _StateRepository();
    guard = WalletMetadataPublicationGuard();
    coordinator = WalletMetadataBackupCoordinator(
      markDirty: MarkWalletMetadataBackupDirtyUsecase(states),
      publishCurrent: () async {
        publishes++;
        return const Ok(
          WalletMetadataPublishOutcome(
            status: WalletMetadataPublishStatus.stored,
          ),
        );
      },
      guard: guard,
      sources: () => [_ChangeSource(changes.stream)],
      successfulSyncs: () => syncs.stream,
      fallbackDelay: const Duration(days: 1),
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await changes.close();
    await syncs.close();
  });

  test('owner changes only mark dirty until a successful sync', () async {
    await coordinator.start();
    changes.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(states.state.dirty, isTrue);
    expect(publishes, 0);

    syncs.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(publishes, 1);
  });

  test('concurrent sync triggers share one in-flight store', () async {
    final completion = Completer<void>();
    coordinator = WalletMetadataBackupCoordinator(
      markDirty: MarkWalletMetadataBackupDirtyUsecase(states),
      publishCurrent: () async {
        publishes++;
        await completion.future;
        return const Ok(
          WalletMetadataPublishOutcome(
            status: WalletMetadataPublishStatus.stored,
          ),
        );
      },
      guard: WalletMetadataPublicationGuard(),
      sources: () => [_ChangeSource(changes.stream)],
      successfulSyncs: () => syncs.stream,
      fallbackDelay: const Duration(days: 1),
    );
    await coordinator.start();
    final first = coordinator.publishNow();
    final second = coordinator.publishNow();
    await Future<void>.delayed(Duration.zero);
    expect(publishes, 1);
    completion.complete();
    await Future.wait([first, second]);
  });

  test('retries a failed durable dirty write before publishing', () async {
    states.updateFailuresRemaining = 1;
    await coordinator.start();
    changes.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(states.state.dirty, isFalse);

    final result = await coordinator.publishNow();

    expect(result, isA<Ok>());
    expect(states.state.dirty, isTrue);
    expect(publishes, 1);
  });

  test('an owner change rearms the delayed no-sync publication', () async {
    coordinator = WalletMetadataBackupCoordinator(
      markDirty: MarkWalletMetadataBackupDirtyUsecase(states),
      publishCurrent: () async {
        publishes++;
        return const Ok(
          WalletMetadataPublishOutcome(
            status: WalletMetadataPublishStatus.stored,
          ),
        );
      },
      guard: WalletMetadataPublicationGuard(),
      sources: () => [_ChangeSource(changes.stream)],
      successfulSyncs: () => syncs.stream,
      fallbackDelay: const Duration(milliseconds: 10),
    );
    await coordinator.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(publishes, 1);

    changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(states.state.dirty, isTrue);
    expect(publishes, 2);
  });

  test('publication suppression waits for the active store', () async {
    final publication = Completer<void>();
    coordinator = WalletMetadataBackupCoordinator(
      markDirty: MarkWalletMetadataBackupDirtyUsecase(states),
      publishCurrent: () async {
        publishes++;
        await publication.future;
        return const Ok(
          WalletMetadataPublishOutcome(
            status: WalletMetadataPublishStatus.stored,
          ),
        );
      },
      guard: guard,
      sources: () => [_ChangeSource(changes.stream)],
      successfulSyncs: () => syncs.stream,
      fallbackDelay: const Duration(days: 1),
    );
    await coordinator.start();
    final storing = coordinator.publishNow();
    await Future<void>.delayed(Duration.zero);
    final acquired = coordinator.beginRecoverySession();
    var suppressionAcquired = false;
    acquired.then((_) => suppressionAcquired = true);
    await Future<void>.delayed(Duration.zero);

    expect(suppressionAcquired, isFalse);
    publication.complete();
    await storing;
    final acquisition = await acquired;
    final suppression = acquisition.suppression;
    expect(
      (await coordinator.publishNow() as Ok).value.status,
      WalletMetadataPublishStatus.notReady,
    );

    suppression.close();
  });

  test('recovery session waits for queued dirty writes', () async {
    final dirtyWrite = Completer<void>();
    states.nextUpdateBlocker = dirtyWrite.future;
    await coordinator.start();

    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    final acquired = coordinator.beginRecoverySession();
    var suppressionAcquired = false;
    acquired.then((_) => suppressionAcquired = true);
    await Future<void>.delayed(Duration.zero);

    expect(suppressionAcquired, isFalse);
    expect(states.state.dirty, isFalse);

    dirtyWrite.complete();
    final acquisition = await acquired;
    final suppression = acquisition.suppression;

    expect(states.state.dirty, isTrue);
    expect(suppressionAcquired, isTrue);
    suppression.close();
  });

  test('recovery session fails closed when queued dirty write fails', () async {
    states.updateFailuresRemaining = 1;
    await coordinator.start();

    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    final acquisition = await coordinator.beginRecoverySession();

    expect(acquisition.failure, isA<WalletMetadataBackupStorageFailure>());
    expect(guard.isPublicationSuppressed, isTrue);
    expect(states.state.dirty, isFalse);
    expect(publishes, 0);

    acquisition.close();

    expect(guard.isPublicationSuppressed, isFalse);
  });

  test(
    'failed facade recovery session owns suppression until closed',
    () async {
      states.updateFailuresRemaining = 1;
      var metadataApplyStarted = false;
      final facade = WalletMetadataBackupFacade(
        GetWalletMetadataBackupStateUsecase(states),
        SetWalletMetadataBackupEnabledUsecase(states),
        MarkWalletMetadataBackupDirtyUsecase(states),
        DeleteWalletMetadataBackupUsecase(
          stateRepository: states,
          remoteRepository: const _UnusedRemoteRepository(),
          keyMaterialPort: const _UnusedKeyMaterialPort(),
        ),
        coordinator,
        () async {
          metadataApplyStarted = true;
          return const Ok(
            internal.WalletMetadataRecoveryResult.noSnapshotFound(),
          );
        },
        ({required createdWalletRefs, required plan}) async {
          metadataApplyStarted = true;
          return const Err(WalletMetadataBackupStorageFailure());
        },
      );
      await coordinator.start();

      changes.add(null);
      await Future<void>.delayed(Duration.zero);
      final session = await facade.beginRecoverySession();

      expect(guard.isPublicationSuppressed, isTrue);

      final recovered = await session.recover(createdWalletRefs: const {});

      expect(recovered, isA<Err>());
      expect(
        (recovered as Err).failure,
        isA<WalletMetadataBackupStorageFailure>(),
      );
      expect(metadataApplyStarted, isFalse);
      expect(guard.isPublicationSuppressed, isTrue);

      session.close();

      expect(guard.isPublicationSuppressed, isFalse);
    },
  );

  test('suppressed action is skipped when queued dirty write fails', () async {
    states.updateFailuresRemaining = 1;
    var actionRan = false;
    await coordinator.start();

    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    final result = await coordinator.suppressPublicationWhile(() async {
      actionRan = true;
      return const Ok(null);
    });

    expect(result, isA<Err>());
    expect(actionRan, isFalse);
    expect(guard.isPublicationSuppressed, isFalse);
  });

  test('marks dirty after a source changes during recovery apply', () async {
    await coordinator.start();
    final suppression = (await coordinator.beginRecoverySession()).suppression;

    await guard.suppressApplyChangesWhile(() async {
      changes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(states.state.dirty, isFalse);
    });

    suppression.close();
    await Future<void>.delayed(Duration.zero);

    expect(states.state.dirty, isTrue);
    expect(publishes, 0);
  });
}

final class _ChangeSource implements WalletMetadataChangeSource {
  @override
  final Stream<void> changes;
  const _ChangeSource(this.changes);
}

final class _StateRepository implements WalletMetadataBackupStateRepository {
  WalletMetadataBackupState state = WalletMetadataBackupState.initial;
  int updateFailuresRemaining = 0;
  Future<void>? nextUpdateBlocker;

  @override
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  fetch() async => Ok(state);

  @override
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>> update(
    WalletMetadataBackupStateUpdate update,
  ) async {
    final blocker = nextUpdateBlocker;
    if (blocker != null) {
      nextUpdateBlocker = null;
      await blocker;
    }
    if (updateFailuresRemaining > 0) {
      updateFailuresRemaining--;
      return const Err(WalletMetadataBackupStorageFailure());
    }
    state = update(state);
    return Ok(state);
  }
}

final class _UnusedRemoteRepository implements WalletMetadataRemoteRepository {
  const _UnusedRemoteRepository();

  @override
  Future<Result<WalletMetadataRemoteFetchResult, WalletMetadataBackupFailure>>
  fetch({required WalletMetadataKeyMaterial keyMaterial}) {
    throw UnimplementedError();
  }

  @override
  Future<Result<WalletMetadataRemoteStoreReceipt, WalletMetadataBackupFailure>>
  store({
    required WalletMetadataKeyMaterial keyMaterial,
    required dynamic snapshot,
    required int generation,
    required String? expectedEtag,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Result<void, WalletMetadataBackupFailure>> delete({
    required WalletMetadataKeyMaterial keyMaterial,
  }) {
    throw UnimplementedError();
  }
}

final class _UnusedKeyMaterialPort implements WalletMetadataKeyMaterialPort {
  const _UnusedKeyMaterialPort();

  @override
  Future<Result<WalletMetadataKeyMaterial, WalletMetadataBackupFailure>>
  deriveLocal() {
    throw UnimplementedError();
  }
}
