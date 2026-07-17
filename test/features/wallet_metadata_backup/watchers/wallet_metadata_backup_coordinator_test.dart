import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_publish_outcome.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/mark_wallet_metadata_backup_dirty_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_publication_guard.dart';
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
    final suppression = await acquired;
    expect(
      (await coordinator.publishNow() as Ok).value.status,
      WalletMetadataPublishStatus.notReady,
    );

    suppression.close();
  });

  test('marks dirty after a source changes during recovery apply', () async {
    await coordinator.start();
    final suppression = await coordinator.beginRecoverySession();

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
  @override
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  fetch() async => Ok(state);
  @override
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>> update(
    WalletMetadataBackupStateUpdate update,
  ) async {
    if (updateFailuresRemaining > 0) {
      updateFailuresRemaining--;
      return const Err(WalletMetadataBackupStorageFailure());
    }
    state = update(state);
    return Ok(state);
  }
}
