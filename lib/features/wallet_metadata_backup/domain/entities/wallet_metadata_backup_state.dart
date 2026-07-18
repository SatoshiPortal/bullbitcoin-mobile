import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';

final RegExp _hashPattern = RegExp(r'^[0-9a-f]{64}$');

final class WalletMetadataBackupVerifiedHead {
  final int remoteGeneration;
  final String remoteEtag;
  final int snapshotRevision;
  final String canonicalContentHash;
  final int verifiedAt;

  WalletMetadataBackupVerifiedHead({
    required this.remoteGeneration,
    required this.remoteEtag,
    required this.snapshotRevision,
    required this.canonicalContentHash,
    required this.verifiedAt,
  }) {
    if (remoteGeneration <= 0) {
      throw ArgumentError.value(remoteGeneration, 'remoteGeneration');
    }
    _validateHash(remoteEtag, 'remoteEtag');
    _validateNonNegativeInt64(snapshotRevision, 'snapshotRevision');
    _validateHash(canonicalContentHash, 'canonicalContentHash');
    _validateNonNegativeInt64(verifiedAt, 'verifiedAt');
  }
}

final class WalletMetadataBackupUnsupportedEnvelope {
  final int remoteGeneration;
  final String remoteEtag;
  final int envelopeVersion;
  final int observedAt;

  WalletMetadataBackupUnsupportedEnvelope({
    required this.remoteGeneration,
    required this.remoteEtag,
    required this.envelopeVersion,
    required this.observedAt,
  }) {
    if (remoteGeneration <= 0) {
      throw ArgumentError.value(remoteGeneration, 'remoteGeneration');
    }
    _validateHash(remoteEtag, 'remoteEtag');
    if (envelopeVersion <= walletMetadataEnvelopeVersion ||
        envelopeVersion > WalletMetadataBackupLimits.maxSignedInt64) {
      throw ArgumentError.value(envelopeVersion, 'envelopeVersion');
    }
    _validateNonNegativeInt64(observedAt, 'observedAt');
  }
}

enum WalletMetadataRecoveryBlockReason { applyInProgress, incompleteApply }

final class WalletMetadataBackupRecoveryBlock {
  final WalletMetadataRecoveryBlockReason reason;
  final int remoteGeneration;
  final String remoteEtag;
  final int snapshotRevision;
  final int observedAt;

  WalletMetadataBackupRecoveryBlock({
    required this.reason,
    required this.remoteGeneration,
    required this.remoteEtag,
    required this.snapshotRevision,
    required this.observedAt,
  }) {
    if (remoteGeneration <= 0) {
      throw ArgumentError.value(remoteGeneration, 'remoteGeneration');
    }
    _validateHash(remoteEtag, 'remoteEtag');
    _validateNonNegativeInt64(snapshotRevision, 'snapshotRevision');
    _validateNonNegativeInt64(observedAt, 'observedAt');
  }

  WalletMetadataBackupRecoveryBlock withReason(
    WalletMetadataRecoveryBlockReason value,
  ) {
    return WalletMetadataBackupRecoveryBlock(
      reason: value,
      remoteGeneration: remoteGeneration,
      remoteEtag: remoteEtag,
      snapshotRevision: snapshotRevision,
      observedAt: observedAt,
    );
  }
}

final class WalletMetadataBackupState {
  static const initial = WalletMetadataBackupState._(
    enabled: false,
    dirty: false,
    dirtyRevision: 0,
    lastAttemptedAt: null,
    lastSucceededAt: null,
    verifiedHead: null,
    unsupportedNewerEnvelope: null,
    recoveryBlock: null,
  );

  final bool enabled;
  final bool dirty;
  final int dirtyRevision;
  final int? lastAttemptedAt;
  final int? lastSucceededAt;
  final WalletMetadataBackupVerifiedHead? verifiedHead;
  final WalletMetadataBackupUnsupportedEnvelope? unsupportedNewerEnvelope;
  final WalletMetadataBackupRecoveryBlock? recoveryBlock;

  factory WalletMetadataBackupState({
    required bool enabled,
    required bool dirty,
    required int dirtyRevision,
    required int? lastAttemptedAt,
    required int? lastSucceededAt,
    required WalletMetadataBackupVerifiedHead? verifiedHead,
    required WalletMetadataBackupUnsupportedEnvelope? unsupportedNewerEnvelope,
    required WalletMetadataBackupRecoveryBlock? recoveryBlock,
  }) {
    if (lastAttemptedAt != null) {
      _validateNonNegativeInt64(lastAttemptedAt, 'lastAttemptedAt');
    }
    if (lastSucceededAt != null) {
      _validateNonNegativeInt64(lastSucceededAt, 'lastSucceededAt');
    }
    _validateNonNegativeInt64(dirtyRevision, 'dirtyRevision');
    return WalletMetadataBackupState._(
      enabled: enabled,
      dirty: dirty,
      dirtyRevision: dirtyRevision,
      lastAttemptedAt: lastAttemptedAt,
      lastSucceededAt: lastSucceededAt,
      verifiedHead: verifiedHead,
      unsupportedNewerEnvelope: unsupportedNewerEnvelope,
      recoveryBlock: recoveryBlock,
    );
  }

  const WalletMetadataBackupState._({
    required this.enabled,
    required this.dirty,
    required this.dirtyRevision,
    required this.lastAttemptedAt,
    required this.lastSucceededAt,
    required this.verifiedHead,
    required this.unsupportedNewerEnvelope,
    required this.recoveryBlock,
  });

  bool get canAttemptStore =>
      enabled &&
      dirty &&
      unsupportedNewerEnvelope == null &&
      recoveryBlock == null;

  WalletMetadataBackupState withEnabled(bool value) {
    if (value == enabled) return this;
    if (!value) return _copy(enabled: false);
    return _copy(
      enabled: true,
      dirty: true,
      dirtyRevision: _nextDirtyRevision(),
    );
  }

  WalletMetadataBackupState markDirty() {
    return _copy(dirty: true, dirtyRevision: _nextDirtyRevision());
  }

  WalletMetadataBackupState recordStoreAttempted(int attemptedAt) {
    _validateNonNegativeInt64(attemptedAt, 'attemptedAt');
    return _copy(lastAttemptedAt: _latest(lastAttemptedAt, attemptedAt));
  }

  WalletMetadataBackupState recordVerifiedHead({
    required WalletMetadataBackupVerifiedHead head,
    required int expectedDirtyRevision,
  }) {
    _validateNonNegativeInt64(expectedDirtyRevision, 'expectedDirtyRevision');
    final current = verifiedHead;
    if (current != null && head.remoteGeneration < current.remoteGeneration) {
      return this;
    }
    return _copy(
      verifiedHead: head,
      lastSucceededAt: _latest(lastSucceededAt, head.verifiedAt),
      dirty: dirtyRevision == expectedDirtyRevision ? false : dirty,
      clearUnsupportedNewerEnvelope: true,
    );
  }

  WalletMetadataBackupState recordNoStoreNeeded({
    required int expectedDirtyRevision,
  }) {
    _validateNonNegativeInt64(expectedDirtyRevision, 'expectedDirtyRevision');
    return _copy(dirty: dirtyRevision == expectedDirtyRevision ? false : dirty);
  }

  WalletMetadataBackupState recordUnsupportedNewerEnvelope(
    WalletMetadataBackupUnsupportedEnvelope unsupported,
  ) {
    return _copy(unsupportedNewerEnvelope: unsupported);
  }

  WalletMetadataBackupState clearRemoteCheckpoint() {
    return _copy(
      clearVerifiedHead: true,
      clearLastSucceededAt: true,
      clearUnsupportedNewerEnvelope: true,
      clearRecoveryBlock: true,
    );
  }

  WalletMetadataBackupState recordRecoveryApplyStarted(
    WalletMetadataBackupRecoveryBlock block,
  ) {
    if (block.reason != WalletMetadataRecoveryBlockReason.applyInProgress) {
      throw ArgumentError.value(block.reason, 'block.reason');
    }
    return _copy(
      dirty: true,
      dirtyRevision: _nextDirtyRevision(),
      recoveryBlock: block,
    );
  }

  WalletMetadataBackupState recordRecoveryApplyBlocked(
    WalletMetadataBackupRecoveryBlock block,
  ) {
    if (block.reason == WalletMetadataRecoveryBlockReason.applyInProgress) {
      throw ArgumentError.value(block.reason, 'block.reason');
    }
    return _copy(dirty: true, recoveryBlock: block);
  }

  WalletMetadataBackupState repairInvalidRecoveryState() {
    if (dirty ||
        recoveryBlock?.reason !=
            WalletMetadataRecoveryBlockReason.applyInProgress) {
      return this;
    }
    return _copy(clearRecoveryBlock: true);
  }

  WalletMetadataBackupState recordRecoveryAppliedClean({
    required WalletMetadataBackupVerifiedHead head,
    required int expectedDirtyRevision,
  }) {
    _validateNonNegativeInt64(expectedDirtyRevision, 'expectedDirtyRevision');
    final current = verifiedHead;
    if (current != null && head.remoteGeneration < current.remoteGeneration) {
      final block = recoveryBlock;
      return block == null
          ? this
          : _copy(
              dirty: true,
              recoveryBlock: block.withReason(
                WalletMetadataRecoveryBlockReason.incompleteApply,
              ),
            );
    }
    return _copy(
      verifiedHead: head,
      lastSucceededAt: _latest(lastSucceededAt, head.verifiedAt),
      dirty: dirtyRevision == expectedDirtyRevision ? false : dirty,
      clearUnsupportedNewerEnvelope: true,
      clearRecoveryBlock: true,
    );
  }

  WalletMetadataBackupState _copy({
    bool? enabled,
    bool? dirty,
    int? dirtyRevision,
    int? lastAttemptedAt,
    int? lastSucceededAt,
    WalletMetadataBackupVerifiedHead? verifiedHead,
    WalletMetadataBackupUnsupportedEnvelope? unsupportedNewerEnvelope,
    WalletMetadataBackupRecoveryBlock? recoveryBlock,
    bool clearLastSucceededAt = false,
    bool clearVerifiedHead = false,
    bool clearUnsupportedNewerEnvelope = false,
    bool clearRecoveryBlock = false,
  }) {
    return WalletMetadataBackupState._(
      enabled: enabled ?? this.enabled,
      dirty: dirty ?? this.dirty,
      dirtyRevision: dirtyRevision ?? this.dirtyRevision,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
      lastSucceededAt: clearLastSucceededAt
          ? null
          : lastSucceededAt ?? this.lastSucceededAt,
      verifiedHead: clearVerifiedHead
          ? null
          : verifiedHead ?? this.verifiedHead,
      unsupportedNewerEnvelope: clearUnsupportedNewerEnvelope
          ? null
          : unsupportedNewerEnvelope ?? this.unsupportedNewerEnvelope,
      recoveryBlock: clearRecoveryBlock
          ? null
          : recoveryBlock ?? this.recoveryBlock,
    );
  }

  int _nextDirtyRevision() {
    if (dirtyRevision == WalletMetadataBackupLimits.maxSignedInt64) {
      throw StateError('wallet metadata dirty revision is exhausted');
    }
    return dirtyRevision + 1;
  }
}

int _latest(int? current, int candidate) {
  if (current == null || candidate > current) return candidate;
  return current;
}

void _validateHash(String value, String name) {
  if (!_hashPattern.hasMatch(value)) {
    throw ArgumentError.value(value, name, 'must be lowercase 32-byte hex');
  }
}

void _validateNonNegativeInt64(int value, String name) {
  if (value < 0 || value > WalletMetadataBackupLimits.maxSignedInt64) {
    throw ArgumentError.value(value, name, 'must be a non-negative int64');
  }
}
