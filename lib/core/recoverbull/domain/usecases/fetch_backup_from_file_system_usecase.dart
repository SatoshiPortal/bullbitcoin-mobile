import 'dart:io';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';

class FetchBackupFromFileSystemUsecase {
  FetchBackupFromFileSystemUsecase();

  Future<BackupInfo> execute(String filePath) async {
    try {
      final backupFile = File(filePath);
      if (!await backupFile.exists()) {
        throw 'Backup file does not exist';
      }
      final backupContent = await backupFile.readAsString();
      final backupInfo = BackupInfo(backupFile: backupContent);
      if (backupInfo.isCorrupted) {
        throw 'Backup file is corrupted';
      }
      return backupInfo;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
