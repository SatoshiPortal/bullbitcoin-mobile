import 'dart:io';

import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/recoverbull/_interface.dart';
import 'package:bb_mobile/locator.dart';
import 'package:recoverbull/recoverbull.dart';

class FileSystemBackupManager extends IRecoverbullManager {
  FileSystemBackupManager();

  final FileStorage fileStorage = locator<FileStorage>();

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

  /// Writes the encrypted backup with backupId, to a storage medium.
  /// Returns the path to the written backup or an error message.
  @override
  Future<(String?, Err?)> saveEncryptedBackup({
    required BullBackup backup,
    String backupFolder = defaultBackupPath,
  }) async {
    try {
      final now = DateTime.now();
      final formattedDate = now.millisecondsSinceEpoch;
      final filename = '${formattedDate}_${backup.id}.json';

      final (appDir, errDir) = await fileStorage.getAppDirectory();
      if (errDir != null) {
        return (null, Err('Failed to get application directory.'));
      }

      final backupDir = await Directory(backupFolder).create(recursive: true);
      final file = File('${backupDir.path}/$filename');

      final (f, errSave) = await fileStorage.saveToFile(file, backup.toJson());
      if (errSave != null) return (null, Err(errSave.message));

      return (file.path, null);
    } catch (e) {
      return (null, Err('Failed to write encrypted backup: $e'));
    }
  }
}
