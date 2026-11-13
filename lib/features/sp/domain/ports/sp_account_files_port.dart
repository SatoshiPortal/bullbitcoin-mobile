import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// The Silent Payments account directory on disk: the revoke sentinel, the
/// recursive delete, and the backup/restore a failed recreate rolls back to.
///
/// Kept apart from the session so only the use cases that genuinely destroy or
/// move wallet data are handed the capability to do it. Every method here is a
/// single file operation; the order they run in during a revoke or a recreate
/// is the use case's business, not this port's.
abstract interface class SpAccountFilesPort {
  /// True when the account dir is present on disk.
  @useResult
  Future<Result<bool, SpFailure>> accountDirExists();

  /// Whether any historical account or backup exists outside the V2 namespace.
  @useResult
  Future<Result<bool, SpFailure>> hasLegacyData();

  /// Whether any account backup exists beside the account directory.
  @useResult
  Future<Result<bool, SpFailure>> hasOrphanBackups();

  /// Require no staging and at most one verified backup matching the binding.
  @useResult
  Future<Result<void, SpFailure>> verifyResumeBackups(SpBackendConfig config);

  /// Create a new V2 directory and its immutable expected-identity marker.
  @useResult
  Future<Result<void, SpFailure>> createAccountDir(SpBackendConfig config);

  /// Verify the existing directory marker before opening it.
  @useResult
  Future<Result<void, SpFailure>> verifyAccountIdentity(SpBackendConfig config);

  /// Verify an existing pending marker without creating or changing it.
  @useResult
  Future<Result<void, SpFailure>> verifyPendingIdentity(SpBackendConfig config);

  /// Write the `.revoked` sentinel into the account dir, so no wallet is ever
  /// loaded from it again. With [skipIfPresent] an existing sentinel is left
  /// untouched, which is what the partial-delete recovery wants.
  @useResult
  Future<Result<void, SpFailure>> writeRevokedSentinel({
    bool skipIfPresent = false,
  });

  /// Recursively delete the account dir. No-op when it is already gone. Used
  /// both by a revoke and by a setup clearing the remains of a failed one.
  @useResult
  Future<Result<void, SpFailure>> deleteAccountDir();

  /// Move the account dir aside to a fresh backup so a failed recreate can roll
  /// back. No-op when the dir is absent. Returns whether a backup was taken.
  @useResult
  Future<Result<bool, SpFailure>> backupAccountDir(SpBackendConfig config);

  /// Roll back a recreate: delete the (partial) account dir, then restore the
  /// backup taken by [backupAccountDir] in its place. Returns whether a backup
  /// was restored.
  @useResult
  Future<Result<bool, SpFailure>> restoreAccountDir(SpBackendConfig config);

  /// Drop the backup taken by [backupAccountDir] after a recreate succeeded.
  /// `Err` when the delete failed; the caller decides what a leftover backup is
  /// worth (the recreated wallet is already live).
  @useResult
  Future<Result<void, SpFailure>> discardBackup(SpBackendConfig config);

  /// Adopt a single verified matching backup when the account dir is absent.
  /// Ambiguous or mismatched backups must remain untouched.
  @useResult
  Future<Result<bool, SpFailure>> adoptNewestBackup(SpBackendConfig config);

  /// Delete a single verified matching backup during an explicit revoke.
  @useResult
  Future<Result<void, SpFailure>> deleteOrphanBackups(SpBackendConfig? config);

  /// True when a `.revoked` sentinel sits in the account dir (a prior revoke
  /// deleted or tried to delete the wallet). Callers treat this as not set up.
  @useResult
  Future<Result<bool, SpFailure>> hasRevokedSentinel();
}
