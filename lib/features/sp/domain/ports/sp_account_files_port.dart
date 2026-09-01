import 'package:bb_mobile/core/utils/result.dart';
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
  Future<Result<bool, SpFailure>> backupAccountDir();

  /// Roll back a recreate: delete the (partial) account dir, then restore the
  /// backup taken by [backupAccountDir] in its place. Returns whether a backup
  /// was restored.
  @useResult
  Future<Result<bool, SpFailure>> restoreAccountDir();

  /// Drop the backup taken by [backupAccountDir] after a recreate succeeded.
  /// `Err` when the delete failed; the caller decides what a leftover backup is
  /// worth (the recreated wallet is already live).
  @useResult
  Future<Result<void, SpFailure>> discardBackup();

  /// Self-heal a crashed recreate: when the account dir is gone but a backup
  /// taken by [backupAccountDir] is still on disk, move the newest one back
  /// into place and drop the rest. Returns whether one was adopted.
  @useResult
  Future<Result<bool, SpFailure>> adoptNewestBackup();

  /// Delete every leftover backup dir. Called on revoke so a wallet the user
  /// destroyed leaves no copy behind.
  @useResult
  Future<Result<void, SpFailure>> deleteOrphanBackups();

  /// True when a `.revoked` sentinel sits in the account dir (a prior revoke
  /// deleted or tried to delete the wallet). Callers treat this as not set up.
  @useResult
  Future<Result<bool, SpFailure>> hasRevokedSentinel();
}
