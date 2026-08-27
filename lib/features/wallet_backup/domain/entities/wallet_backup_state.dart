import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_envelope.dart';

final class WalletBackupState {
  final bool enabled;
  final bool dirty;
  final int dirtyRevision;
  final int? lastAttemptedAt;
  final int? lastSucceededAt;
  final int remoteGeneration;
  final String? remoteEtag;
  final String? contentHash;
  final int? unsupportedVersion;
  final bool recoveryBlocked;

  WalletBackupState({
    required this.enabled,
    required this.dirty,
    required this.dirtyRevision,
    required this.lastAttemptedAt,
    required this.lastSucceededAt,
    required this.remoteGeneration,
    required String? remoteEtag,
    required String? contentHash,
    required this.unsupportedVersion,
    this.recoveryBlocked = false,
  }) : remoteEtag = _normalizeHash(remoteEtag),
       contentHash = _normalizeHash(contentHash) {
    if (dirtyRevision < 0) {
      throw ArgumentError.value(
        dirtyRevision,
        'dirtyRevision',
        'wallet backup dirty revision must be non-negative',
      );
    }
    if (lastAttemptedAt case final value? when value < 0) {
      throw ArgumentError.value(
        value,
        'lastAttemptedAt',
        'wallet backup attempt timestamp must be non-negative',
      );
    }
    if (lastSucceededAt case final value? when value < 0) {
      throw ArgumentError.value(
        value,
        'lastSucceededAt',
        'wallet backup success timestamp must be non-negative',
      );
    }
    if (remoteGeneration < 0) {
      throw ArgumentError.value(
        remoteGeneration,
        'remoteGeneration',
        'wallet backup remote generation must be non-negative',
      );
    }
    if (remoteGeneration == 0 &&
        (this.remoteEtag != null ||
            this.contentHash != null ||
            lastSucceededAt != null)) {
      throw ArgumentError(
        'wallet backup without a remote generation cannot have a checkpoint',
      );
    }
    if (remoteGeneration > 0 &&
        (this.remoteEtag == null ||
            this.contentHash == null ||
            lastSucceededAt == null)) {
      throw ArgumentError(
        'wallet backup remote generation requires a complete checkpoint',
      );
    }
    if (unsupportedVersion case final value?
        when value <= WalletBackupEnvelope.currentVersion) {
      throw ArgumentError.value(
        value,
        'unsupportedVersion',
        'blocked wallet backup version must be newer than this client',
      );
    }
  }
}

String? _normalizeHash(String? value) {
  if (value == null) return null;
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'hash',
      'wallet backup checkpoint values must be 32-byte hexadecimal hashes',
    );
  }
  return normalized;
}
