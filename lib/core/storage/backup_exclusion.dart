import 'dart:io' show File, Platform;

import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:meta/meta.dart';

/// Marks the local databases as "do not back up" on iOS.
///
/// Why this exists: the databases live in `NSDocumentDirectory`, which
/// iCloud and iTunes back up, while their encryption key lives in the
/// keychain under `first_unlock_this_device`, which is *not* restored
/// onto a different device. Restoring a backup onto a new phone would
/// therefore reproduce an encrypted database with no key to open it,
/// and the fail-closed path would stop the app from starting.
///
/// Excluding the databases loses nothing that was previously
/// recoverable: wallet seeds already use `first_unlock_this_device`, so
/// a device-to-device restore never carried working wallets. It only
/// stops the restore from carrying a database that can't be read.
///
/// Best effort by design. If the platform channel fails the app must
/// still start — a database that is backed up is a future migration
/// problem, a startup that throws here is an outage now.
abstract final class BackupExclusion {
  static const _channel = MethodChannel('bullbitcoin.com/backup_exclusion');

  /// Sidecars SQLite creates next to a database file. They hold the
  /// same (encrypted) pages, and an orphaned `-wal` restored without
  /// its database is at best useless, so they get the same treatment.
  static const _sidecarSuffixes = ['', '-wal', '-shm'];

  /// Excludes [databasePaths] and their SQLite sidecars from device
  /// backups. Paths that don't exist yet are skipped — call this again
  /// once they do (see the app-lifecycle sweep in `main.dart`).
  static Future<void> excludeDatabases(Iterable<String> databasePaths) async {
    if (!Platform.isIOS) return;

    final paths = resolvePaths(databasePaths);
    if (paths.isEmpty) return;

    try {
      await _channel.invokeMethod<void>('excludeFromBackup', {'paths': paths});
    } on PlatformException catch (e) {
      log.warning('Could not exclude databases from backup: ${e.code}');
    } on MissingPluginException {
      // An older Runner without the handler. Not fatal, and not worth a
      // warning on every launch of a build that simply predates it.
      log.fine('Backup-exclusion channel unavailable');
    }
  }

  /// Expands each database path into the set of files that actually
  /// exist right now.
  ///
  /// Filtering here rather than natively keeps the channel payload
  /// honest: `setResourceValues` throws on a missing file, and a launch
  /// where the payjoin database has not been opened yet would otherwise
  /// report a failure for a file that is simply not there yet.
  @visibleForTesting
  static List<String> resolvePaths(Iterable<String> databasePaths) => [
    for (final path in databasePaths)
      for (final suffix in _sidecarSuffixes)
        if (File('$path$suffix').existsSync()) '$path$suffix',
  ];
}
