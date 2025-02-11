import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_pkg/backup/_interface.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/locator.dart';
import 'package:hex/hex.dart';

class FileSystemBackupManager extends IBackupManager {
  final FileStorage fileStorage = locator<FileStorage>();

  FileSystemBackupManager();

  /// Deletes the encrypted backup from the specified directory.
  /// Returns the path to the deleted backup or an error message.
  @override
  Future<(String?, Err?)> removeEncryptedBackup({
    required String backupName,
    String backupFolder = defaultBackupPath,
  }) async {
    try {
      final result = await fileStorage.deleteFile(backupName);
      if (result == null) return (null, Err('Failed to delete file.'));
      return (result.message, null);
    } catch (e) {
      return (null, Err('Failed to delete encrypted backup: $e'));
    }
  }

  /// Reads the encrypted backup from the specified file.
  /// Returns a map containing the backup data and the backup ID, or an error message.
  @override
  Future<(Map<String, dynamic>?, Err?)> loadEncryptedBackup({
    required String encrypted,
  }) async {
    try {
      final decodeEncryptedFile = jsonDecode(utf8.decode(HEX.decode(encrypted)))
          as Map<String, dynamic>;
      final id = decodeEncryptedFile['id']?.toString() ?? '';
      if (id.isEmpty) {
        return (null, Err("Corrupted backup file"));
      }
      return (decodeEncryptedFile, null);
    } catch (e) {
      return (null, Err('Failed to read encrypted backup: $e'));
    }
  }

  /// Writes the encrypted backup with backupId, to a storage medium.
  /// Returns the path to the written backup or an error message.
  @override
  Future<(String?, Err?)> saveEncryptedBackup({
    required String encrypted,
    String backupFolder = defaultBackupPath,
  }) async {
    try {
      final decodeEncryptedFile = jsonDecode(encrypted) as Map<String, dynamic>;
      final backupId = decodeEncryptedFile['id']?.toString() ?? '';
      final now = DateTime.now();
      final formattedDate = now.millisecondsSinceEpoch;
      final filename = '${formattedDate}_$backupId.json';

      final (appDir, errDir) = await fileStorage.getAppDirectory();
      if (errDir != null) {
        return (null, Err('Failed to get application directory.'));
      }

      final backupDir = await Directory(backupFolder).create(recursive: true);
      final file = File('${backupDir.path}/$filename');

      final (f, errSave) = await fileStorage.saveToFile(
        file,
        HEX.encode(utf8.encode(encrypted)),
      );
      if (errSave != null) {
        return (null, Err(errSave.message));
      }
      return (file.path, null);
    } catch (e) {
      return (null, Err('Failed to write encrypted backup: $e'));
    }
  }
}
