import 'dart:convert';

import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'dart:io';

import 'package:bb_mobile/features/sp/data/sp_storage_names.dart';
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

  Future<bool> _directoryExists(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.directory) {
      throw const FormatException('SP account path is not a directory');
    }
    return true;
  }

  Future<bool> accountDirExists() async =>
      _directoryExists(await _accountDir());

  Future<bool> hasRevokedSentinel() async {
    final dir = await _accountDir();
    if (!await _directoryExists(dir)) return false;
    final type = await FileSystemEntity.type(
      _sentinelFile(dir).path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.file) {
      throw const FormatException('SP sentinel is not a file');
    }
    return true;
  }

  Future<bool> hasLegacyData() async {
    final root = Directory(await dataDir());
    if (!await root.exists()) return false;
    await for (final entry in root.list(followLinks: false)) {
      final name = entry.path.split(Platform.pathSeparator).last;
      if (name == SpStorageNames.legacyAccountName ||
          name.startsWith(
            '${SpStorageNames.legacyAccountName}$_backupSuffix',
          )) {
        return true;
      }
    }
    return false;
  }

  Map<String, Object> _identity(SpBackendConfig config) {
    final source = config.source;
    if (source == null) throw const FormatException('SP identity unavailable');
    return {
      'version': 1,
      'network': config.network.name,
      'walletId': source.walletId,
      'secretId': source.secretId,
      'externalDescriptor': source.externalDescriptor,
      'internalDescriptor': source.internalDescriptor,
      'spAddress': source.spAddress,
    };
  }

  Future<bool> _matches(
    Directory directory,
    SpBackendConfig config, {
    bool requireVerified = true,
  }) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return false;
    }
    final marker = File('${directory.path}/${SpStorageNames.identityMarker}');
    if (await FileSystemEntity.type(marker.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return false;
    }
    try {
      final decoded = jsonDecode(await marker.readAsString());
      if (decoded is! Map<String, dynamic>) return false;
      final expected = _identity(config);
      final status = decoded['status'];
      return decoded.length == expected.length + 1 &&
          (status == 'verified' || (!requireVerified && status == 'pending')) &&
          expected.entries.every((entry) => decoded[entry.key] == entry.value);
    } catch (_) {
      return false;
    }
  }

  Future<void> verifyOpenIdentity(SpBackendConfig config) async {
    if (!await _matches(await _accountDir(), config, requireVerified: false)) {
      throw const FormatException('SP account identity mismatch');
    }
  }

  Future<void> verifyPendingIdentity(SpBackendConfig config) async {
    final directory = await _accountDir();
    if (!await _matches(directory, config, requireVerified: false) ||
        await _matches(directory, config)) {
      throw const FormatException('SP pending identity mismatch');
    }
  }

  Future<void> verifyAccountIdentity(SpBackendConfig config) async {
    if (!await _matches(await _accountDir(), config)) {
      throw const FormatException('SP account identity mismatch');
    }
  }

  Future<void> createAccountDir(SpBackendConfig config) async {
    final target = await _accountDir();
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const FileSystemException('SP account already exists');
    }
    final root = Directory(await dataDir());
    final staged = await root.createTemp('sp_v2.new-');
    try {
      final marker = File('${staged.path}/${SpStorageNames.identityMarker}');
      await marker.writeAsString(
        jsonEncode({..._identity(config), 'status': 'pending'}),
        flush: true,
      );
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const FileSystemException('SP account already exists');
      }
      await staged.rename(target.path);
    } catch (_) {
      if (await staged.exists()) await staged.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> commitAccountIdentity(SpBackendConfig config) async {
    final directory = await _accountDir();
    if (!await _matches(directory, config, requireVerified: false)) {
      throw const FormatException('SP account identity mismatch');
    }
    if (await _matches(directory, config)) return;
    final temporary = File(
      '${directory.path}/${SpStorageNames.identityMarker}.tmp',
    );
    final expected = jsonEncode({..._identity(config), 'status': 'verified'});
    final tempType = await FileSystemEntity.type(
      temporary.path,
      followLinks: false,
    );
    if (tempType == FileSystemEntityType.notFound) {
      await temporary.create(exclusive: true);
      await temporary.writeAsString(expected, flush: true);
    } else if (tempType != FileSystemEntityType.file ||
        await temporary.readAsString() != expected) {
      throw const FormatException('SP identity staging mismatch');
    }
    await temporary.rename(
      '${directory.path}/${SpStorageNames.identityMarker}',
    );
  }

  /// Write the `.revoked` sentinel into the account dir. With [skipIfPresent]
  /// it leaves an existing sentinel untouched (the partial-delete recovery).
  Future<void> writeRevokedSentinel({bool skipIfPresent = false}) async {
    final directory = await _accountDir();
    if (!await _directoryExists(directory)) {
      throw const FormatException('SP account directory missing');
    }
    final sentinel = _sentinelFile(directory);
    final type = await FileSystemEntity.type(sentinel.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw const FormatException('SP sentinel is not a file');
    }
    if (skipIfPresent && type == FileSystemEntityType.file) return;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    await sentinel.writeAsString('revoked-at: $timestamp\n', flush: true);
  }

  /// Recursively delete the account dir. No-op when it is already gone.
  Future<void> deleteAccountDir() async {
    final accountDir = await _accountDir();
    if (await _directoryExists(accountDir)) {
      await accountDir.delete(recursive: true);
    }
  }

  /// Move the account dir aside to a fresh backup. Returns whether one was
  /// taken; false when there is no account dir.
  Future<bool> backupAccountDir(SpBackendConfig config) async {
    final accountDir = await _accountDir();
    if (!await _directoryExists(accountDir)) {
      _recreateBackupDir = null;
      return false;
    }
    if (!await _matches(accountDir, config)) {
      throw const FormatException('SP account identity mismatch');
    }
    final backupDir = Directory(
      '${accountDir.path}$_backupSuffix${DateTime.now().microsecondsSinceEpoch}',
    );
    await accountDir.rename(backupDir.path);
    _recreateBackupDir = backupDir;
    return true;
  }

  /// Restore a verified backup only when no account directory exists.
  Future<bool> restoreAccountDir(SpBackendConfig config) async {
    final accountDir = await _accountDir();
    final backupDir = _recreateBackupDir;
    if (backupDir == null || !await _directoryExists(backupDir)) return false;
    if (!await _matches(backupDir, config)) {
      throw const FormatException('SP backup identity mismatch');
    }
    if (await _directoryExists(accountDir)) {
      // Even the same identity may contain newer account data.
      throw const FormatException('SP account recovery required');
    }
    await backupDir.rename(accountDir.path);
    _recreateBackupDir = null;
    return true;
  }

  /// Drop the backup after a recreate succeeded. Returns whether the backup is
  /// gone; false when the delete failed, so the caller can report it.
  Future<bool> discardBackup(SpBackendConfig config) async {
    final backupDir = _recreateBackupDir;
    if (backupDir == null || !await _directoryExists(backupDir)) return true;
    if (!await _matches(backupDir, config)) {
      throw const FormatException('SP backup identity mismatch');
    }
    try {
      await backupDir.delete(recursive: true);
      _recreateBackupDir = null;
      return true;
    } on FileSystemException catch (_) {
      return false;
    }
  }

  Future<bool> hasIncompleteStaging() async {
    final root = Directory(await dataDir());
    if (!await root.exists()) return false;
    await for (final entry in root.list(followLinks: false)) {
      final name = entry.path.split(Platform.pathSeparator).last;
      if (name.startsWith('sp_v2.new-')) return true;
    }
    return false;
  }

  Future<void> verifyResumeBackups(SpBackendConfig config) async {
    if (await hasIncompleteStaging()) {
      throw const FormatException('SP incomplete staging');
    }
    final backups = await findOrphanBackups();
    if (backups.length > 1 ||
        (backups.length == 1 && !await _matches(backups.single, config))) {
      throw const FormatException('SP backup identity mismatch');
    }
  }

  /// Backup dirs sitting next to the account dir, newest first.
  Future<List<Directory>> findOrphanBackups() async {
    final root = Directory(await dataDir());
    if (!await root.exists()) return const [];
    final prefix = '${SpStorageNames.accountName}$_backupSuffix';
    final found = <(int, Directory)>[];
    await for (final entry in root.list(followLinks: false)) {
      final name = entry.path.split(Platform.pathSeparator).last;
      if (!name.startsWith(prefix)) continue;
      final stamp = int.tryParse(name.substring(prefix.length));
      if (stamp == null || entry is! Directory) {
        throw const FormatException('SP backup entry is invalid');
      }
      found.add((stamp, entry));
    }
    found.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final (_, dir) in found) dir];
  }

  /// Adopt a single matching verified backup when the account dir is absent.
  /// Ambiguous backups and incomplete staging remain untouched.
  Future<bool> adoptNewestBackup(SpBackendConfig config) async {
    final accountDir = await _accountDir();
    if (await hasIncompleteStaging()) {
      throw const FormatException('SP incomplete staging');
    }
    final backups = await findOrphanBackups();
    if (backups.length > 1) {
      throw const FormatException('SP backup recovery required');
    }
    if (await _directoryExists(accountDir) || backups.isEmpty) return false;
    if (!await _matches(backups.single, config)) {
      throw const FormatException('SP backup identity mismatch');
    }
    await backups.single.rename(accountDir.path);
    _recreateBackupDir = null;
    return true;
  }

  /// Delete every leftover backup dir.
  Future<void> deleteOrphanBackups(SpBackendConfig? config) async {
    final backups = await findOrphanBackups();
    if (backups.length > 1 || await hasIncompleteStaging()) {
      throw const FormatException('SP backup recovery required');
    }
    for (final backup in backups) {
      if (config == null || !await _matches(backup, config)) {
        throw const FormatException('SP backup identity mismatch');
      }
      await backup.delete(recursive: true);
    }
    _recreateBackupDir = null;
  }

  Future<Directory> _accountDir() async =>
      Directory('${await dataDir()}/${SpStorageNames.accountName}');

  File _sentinelFile(Directory accountDir) =>
      File('${accountDir.path}/${SpStorageNames.revokedSentinelFile}');
}
