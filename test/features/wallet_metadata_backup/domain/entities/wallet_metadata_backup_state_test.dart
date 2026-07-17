import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const etag =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const hash =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test('activation marks pre-existing metadata dirty', () {
    final state = WalletMetadataBackupState.initial.withEnabled(true);

    expect(state.enabled, isTrue);
    expect(state.dirty, isTrue);
    expect(state.dirtyRevision, 1);
    expect(state.canAttemptStore, isTrue);
  });

  test('verified store only clears the captured dirty revision', () {
    final captured = WalletMetadataBackupState.initial.withEnabled(true);
    final changedDuringStore = captured.markDirty();
    final result = changedDuringStore.recordVerifiedHead(
      head: WalletMetadataBackupVerifiedHead(
        remoteGeneration: 1,
        remoteEtag: etag,
        snapshotRevision: 1,
        canonicalContentHash: hash,
        verifiedAt: 100,
      ),
      expectedDirtyRevision: captured.dirtyRevision,
    );

    expect(result.dirty, isTrue);
    expect(result.dirtyRevision, 2);
    expect(result.verifiedHead?.remoteGeneration, 1);
  });

  test('disabling preserves dirty work and the remote checkpoint', () {
    final stored = WalletMetadataBackupState.initial
        .withEnabled(true)
        .recordVerifiedHead(
          head: WalletMetadataBackupVerifiedHead(
            remoteGeneration: 2,
            remoteEtag: etag,
            snapshotRevision: 4,
            canonicalContentHash: hash,
            verifiedAt: 100,
          ),
          expectedDirtyRevision: 1,
        )
        .markDirty()
        .withEnabled(false);

    expect(stored.enabled, isFalse);
    expect(stored.dirty, isTrue);
    expect(stored.verifiedHead?.remoteEtag, etag);
  });

  test('recovery only clears the dirty revision captured at apply start', () {
    final block = WalletMetadataBackupRecoveryBlock(
      reason: WalletMetadataRecoveryBlockReason.applyInProgress,
      remoteGeneration: 1,
      remoteEtag: etag,
      snapshotRevision: 1,
      observedAt: 100,
    );
    final started = WalletMetadataBackupState.initial
        .recordRecoveryApplyStarted(block);
    final changedDuringRecovery = started.withEnabled(true);

    final result = changedDuringRecovery.recordRecoveryAppliedClean(
      head: WalletMetadataBackupVerifiedHead(
        remoteGeneration: 1,
        remoteEtag: etag,
        snapshotRevision: 1,
        canonicalContentHash: hash,
        verifiedAt: 101,
      ),
      expectedDirtyRevision: started.dirtyRevision,
    );

    expect(result.enabled, isTrue);
    expect(result.dirty, isTrue);
    expect(result.dirtyRevision, 2);
    expect(result.recoveryBlock, isNull);
  });
}
