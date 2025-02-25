import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/recoverbull/_interface.dart';
import 'package:bb_mobile/locator.dart';

class FileSystemBackupManager extends IBackupManager {
  final FileStorage fileStorage = locator<FileStorage>();

  FileSystemBackupManager();

  /// Deletes the encrypted backup from the specified directory.
  /// Returns the path to the deleted backup or an error message.
  @override
  Future<(String?, Err?)> removeEncryptedBackup({
    required String path,
  }) async {
    try {
      final result = await fileStorage.deleteFile(path);
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
      final decodeEncryptedFile = jsonDecode(encrypted) as Map<String, dynamic>;
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
      final backupId = jsonDecode(encrypted)['id'] as String;
      final now = DateTime.now();
      final formattedDate = now.millisecondsSinceEpoch;
      final filename = '${formattedDate}_$backupId.json';

      final (appDir, errDir) = await fileStorage.getAppDirectory();
      if (errDir != null) {
        return (null, Err('Failed to get application directory.'));
      }

      final backupDir = await Directory(backupFolder).create(recursive: true);
      final file = File('${backupDir.path}/$filename');

      final (f, errSave) = await fileStorage.saveToFile(file, encrypted);
      if (errSave != null) return (null, Err(errSave.message));

      return (file.path, null);
    } catch (e) {
      return (null, Err('Failed to write encrypted backup: $e'));
    }
  }
}
