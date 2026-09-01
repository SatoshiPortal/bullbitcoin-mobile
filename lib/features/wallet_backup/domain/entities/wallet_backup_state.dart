import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';

/// The one durable fence around applying a snapshot to local storage.
///
/// It replaces the former recoveryBlocked and reconciliationPending pair, so
/// a half-applied recovery and a head conflict cannot disagree with each other
/// (spec F9, 17).
enum WalletBackupRecoveryState {
  /// Nothing is being applied and nothing needs the user.
  idle,

  /// A snapshot is being written to local storage right now. A process that
  /// dies here leaves this value behind, which is how an interrupted apply is
  /// recognised on the next read.
  applying,

  /// An apply did not complete, or another installation holds the head. Local
  /// work stays dirty and publication refuses until the user resolves it.
  needsAttention,
}

final class WalletBackupState {
  final bool enabled;

  /// The latest committed backup-relevant local mutation.
  final int localRevision;

  /// The local revision a successful store acknowledged.
  final int uploadedRevision;
  final int? lastSucceededAt;
  final int? unsupportedVersion;
  final WalletBackupRecoveryState recoveryState;
  final WalletBackupRecoveryStatus? lastRecoveryStatus;
  final String? customServerUrl;

  /// The last authenticated remote head, or null while none is trusted.
  ///
  /// A publication with a checkpoint stores straight against it; without one it
  /// fetches the head first (spec 17, F7).
  final WalletBackupRemoteCheckpoint? remoteCheckpoint;

  WalletBackupState({
    required this.enabled,
    required this.localRevision,
    required this.uploadedRevision,
    required this.lastSucceededAt,
    required this.unsupportedVersion,
    this.recoveryState = WalletBackupRecoveryState.idle,
    this.lastRecoveryStatus,
    this.customServerUrl,
    this.remoteCheckpoint,
  }) {
    if (localRevision < 0) {
      throw ArgumentError.value(
        localRevision,
        'localRevision',
        'wallet backup local revision must be non-negative',
      );
    }
    if (uploadedRevision < 0 || uploadedRevision > localRevision) {
      throw ArgumentError.value(
        uploadedRevision,
        'uploadedRevision',
        'wallet backup uploaded revision must not exceed the local revision',
      );
    }
    if (lastSucceededAt case final value? when value < 0) {
      throw ArgumentError.value(
        value,
        'lastSucceededAt',
        'wallet backup success timestamp must be non-negative',
      );
    }
    if (unsupportedVersion case final value?
        when value <= WalletBackupSnapshot.currentVersion) {
      throw ArgumentError.value(
        value,
        'unsupportedVersion',
        'blocked wallet backup version must be newer than this client',
      );
    }
    if (customServerUrl != null && customServerUrl!.isEmpty) {
      throw ArgumentError.value(
        customServerUrl,
        'customServerUrl',
        'custom backup server URL must not be empty',
      );
    }
  }

  /// Local work the remote has not acknowledged.
  bool get dirty => localRevision > uploadedRevision;

  /// Publication is fenced while a snapshot is being applied or an apply left
  /// something for the user. A version block is deliberately not part of this:
  /// it is reported as its own failure rather than hidden behind the fence.
  bool get recoveryBlocked => recoveryState != WalletBackupRecoveryState.idle;

  /// The user has to choose between recovering, comparing, and replacing.
  bool get needsAttention =>
      recoveryState == WalletBackupRecoveryState.needsAttention;

  bool get canPublish =>
      enabled && dirty && !recoveryBlocked && unsupportedVersion == null;
}
