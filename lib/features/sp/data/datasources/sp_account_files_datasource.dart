import 'dart:io';

import 'package:bb_mobile/features/sp/data/sp_storage_names.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:path_provider/path_provider.dart';

/// The Silent Payments account directory on disk.
///
/// Wraps `dart:io` and `path_provider`. Every method throws on failure; the
/// repository is the try/catch boundary that turns that into a failure. All
/// file work is async: a recursive delete of the account dir moves hundreds of
/// MB and would otherwise block the UI isolate.
class SpAccountFilesDatasource {
  /// Name suffix of a backup dir, followed by the microsecond timestamp that
  /// makes it unique and orders backups.
  static const String _backupSuffix = '.backup-';

  /// Backup dir a recreate moved the account aside to, so a failed create can
  /// be rolled back. Set by [backupAccountDir], cleared by restore/discard.
  Directory? _recreateBackupDir;

  Future<String> dataDir() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    return appDocsDir.path;
  }

  Future<bool> accountDirExists() async => (await _accountDir()).exists();

  Future<bool> hasRevokedSentinel() async =>
      _sentinelFile(await _accountDir()).exists();

  /// Write the `.revoked` sentinel into the account dir. With [skipIfPresent]
  /// it leaves an existing sentinel untouched (the partial-delete recovery).
  Future<void> writeRevokedSentinel({bool skipIfPresent = false}) async {
    final sentinel = _sentinelFile(await _accountDir());
    if (skipIfPresent && await sentinel.exists()) return;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    await sentinel.writeAsString('revoked-at: $timestamp\n', flush: true);
  }

  /// Recursively delete the account dir. No-op when it is already gone.
  Future<void> deleteAccountDir() async {
    final accountDir = await _accountDir();
    if (await accountDir.exists()) {
      await accountDir.delete(recursive: true);
    }
  }

  /// Move the account dir aside to a fresh backup. Returns whether one was
  /// taken; false when there is no account dir.
  Future<bool> backupAccountDir() async {
    final accountDir = await _accountDir();
    if (!await accountDir.exists()) {
      _recreateBackupDir = null;
      return false;
    }
    final backupDir = Directory(
      '${accountDir.path}$_backupSuffix${DateTime.now().microsecondsSinceEpoch}',
    );
    await accountDir.rename(backupDir.path);
    _recreateBackupDir = backupDir;
    return true;
  }

  /// Delete the (partial) account dir, then put the backup back in its place.
  /// Returns whether a backup was restored.
  Future<bool> restoreAccountDir() async {
    final accountDir = await _accountDir();
    if (await accountDir.exists()) {
      await accountDir.delete(recursive: true);
    }
    final backupDir = _recreateBackupDir;
    if (backupDir == null || !await backupDir.exists()) return false;
    await backupDir.rename(accountDir.path);
    _recreateBackupDir = null;
    return true;
  }

  /// Drop the backup after a recreate succeeded. Returns whether the backup is
  /// gone; false when the delete failed, so the caller can report it.
  Future<bool> discardBackup() async {
    final backupDir = _recreateBackupDir;
    _recreateBackupDir = null;
    if (backupDir == null || !await backupDir.exists()) return true;
    try {
      await backupDir.delete(recursive: true);
      return true;
    } on FileSystemException catch (e) {
      log.warning('SpAccountFiles: backup discard failed: $e');
      return false;
    }
  }

  /// Backup dirs sitting next to the account dir, newest first.
  Future<List<Directory>> findOrphanBackups() async {
    final root = Directory(await dataDir());
    if (!await root.exists()) return const [];
    final prefix = '${SpStorageNames.accountName}$_backupSuffix';
    final found = <(int, Directory)>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final name = entry.path.split(Platform.pathSeparator).last;
      if (!name.startsWith(prefix)) continue;
      final stamp = int.tryParse(name.substring(prefix.length));
      if (stamp == null) continue;
      found.add((stamp, entry));
    }
    found.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final (_, dir) in found) dir];
  }

  /// Self-heal a recreate that died between the backup and the create: with no
  /// account dir but a backup on disk, move the newest one back into place and
  /// delete the rest. Returns whether one was adopted.
  Future<bool> adoptNewestBackup() async {
    final accountDir = await _accountDir();
    if (await accountDir.exists()) return false;
    final backups = await findOrphanBackups();
    if (backups.isEmpty) return false;
    await backups.first.rename(accountDir.path);
    _recreateBackupDir = null;
    for (final stale in backups.skip(1)) {
      await stale.delete(recursive: true);
    }
    return true;
  }

  /// Delete every leftover backup dir.
  Future<void> deleteOrphanBackups() async {
    _recreateBackupDir = null;
    for (final backup in await findOrphanBackups()) {
      await backup.delete(recursive: true);
    }
  }

  /// Delete every advisory lock left in the account dir. A lock that cannot be
  /// deleted is logged, not fatal: the create reports the real failure.
  Future<void> clearStaleLocks() async {
    final accountDir = await _accountDir();
    for (final name in SpStorageNames.lockFiles) {
      final lock = File('${accountDir.path}/$name');
      if (!await lock.exists()) continue;
      try {
        await lock.delete();
      } catch (e) {
        log.warning('SpAccountFiles: stale lock delete failed ($name): $e');
      }
    }
  }

  Future<Directory> _accountDir() async =>
      Directory('${await dataDir()}/${SpStorageNames.accountName}');

  File _sentinelFile(Directory accountDir) =>
      File('${accountDir.path}/${SpStorageNames.revokedSentinelFile}');
}
