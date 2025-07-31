import 'dart:io';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';

class FetchBackupFromFileSystemUsecase {
  FetchBackupFromFileSystemUsecase();

  Future<BackupInfo> execute(String filePath) async {
    try {
      final backupFile = File(filePath);
      if (!await backupFile.exists()) {
        throw BackupCorruptedError;
      }
      final backupContent = await backupFile.readAsString();
      final backupInfo = BackupInfo(backupFile: backupContent);
      if (backupInfo.isCorrupted) {
        throw const BackupCorruptedError();
      }
      return backupInfo;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
