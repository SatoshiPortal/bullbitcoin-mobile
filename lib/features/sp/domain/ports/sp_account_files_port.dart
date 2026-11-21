import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// The Silent Payments account directory on disk: the revoke sentinel, the
/// recursive delete, and recovery of backups created by older app versions.
///
/// Kept apart from the session so only the use cases that genuinely destroy or
/// move wallet data are handed the capability to do it. Every method here is a
/// single file operation; the order they run in during revoke or recovery
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

  /// Recover a legacy backup: when the account dir is gone but a backup
  /// is still on disk, move the newest one back
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
