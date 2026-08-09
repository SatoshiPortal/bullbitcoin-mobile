import 'dart:io' show File;

import 'package:bb_mobile/core/storage/database_encryption_key_store.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/utils/report.dart' show ReportCategory;
import 'package:meta/meta.dart';

/// Deletes the local databases and the key that opens them, so the next
/// launch starts from an empty install.
///
/// This is the only escape from the fail-closed path: when a database
/// exists whose encryption key is gone, nothing can read it and no
/// amount of retrying will change that. It is destructive and
/// unrecoverable without the user's own wallet backup, so it must never
/// run on its own — only behind an explicit, confirmed user action (see
/// `LocalDataRecoveryScreen`).
///
/// Deliberately *not* a wipe of secure storage: wallet seeds live there,
/// and destroying them turns "your local cache is unreadable" into
/// "your funds are gone". Orphaned seeds are re-associated when the user
/// restores from their backup.
abstract final class LocalDatabaseReset {
  /// Suffixes of every file the storage layer can leave next to a
  /// database. The last two are the crash-safe encryption migration's
  /// scratch and rollback copies — a reset that left a
  /// `.plaintext-backup` behind would resurrect the very database it
  /// was asked to remove on the next launch's recovery pass.
  static const _suffixes = [
    '',
    '-wal',
    '-shm',
    '.encryption-tmp',
    '.plaintext-backup',
  ];

  /// Deletes [databasePaths] with all their sidecars, then the
  /// encryption key.
  ///
  /// Order is load-bearing: the key goes last, and is deleted only if
  /// every database file was removed. An interruption or deletion
  /// failure therefore leaves the key available for any database that
  /// remains rather than manufacturing a keyless encrypted database.
  static Future<void> run(
    Iterable<String> databasePaths, {
    @visibleForTesting Future<void> Function(File file)? deleteFile,
  }) async {
    log.warning('Resetting local databases at the user request');

    Object? firstFailure;
    StackTrace? firstFailureTrace;

    for (final path in databasePaths) {
      for (final suffix in _suffixes) {
        final file = File('$path$suffix');
        try {
          if (await file.exists()) {
            await (deleteFile?.call(file) ?? file.delete());
          }
        } catch (e, s) {
          // Try every file so one failure doesn't leave avoidable
          // leftovers, but retain the key if any deletion failed.
          firstFailure ??= e;
          firstFailureTrace ??= s;
          log.severe(
            message: 'Could not delete local database file',
            error: e,
            trace: s,
            category: ReportCategory.migration,
          );
        }
      }
    }

    if (firstFailure != null) {
      Error.throwWithStackTrace(firstFailure, firstFailureTrace!);
    }
    await DatabaseEncryptionKeyStore.delete();
  }
}
